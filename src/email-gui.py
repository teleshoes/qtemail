#!/usr/bin/python
#qtbtn.py
#Copyright 2012,2015 Elliot Wolk
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

from PySide.QtGui import *
from PySide.QtCore import *
from PySide.QtDeclarative import *

import os
import os.path
import re
import signal
import sys
import subprocess

PLATFORM_OTHER = 0
PLATFORM_HARMATTAN = 1

signal.signal(signal.SIGINT, signal.SIG_DFL)

PAGE_INITIAL_SIZE = 200
PAGE_MORE_SIZE = 200

UNREAD_COUNTS = os.getenv("HOME") + "/.unread-counts"
EMAIL_DIR = os.getenv("HOME") + "/.cache/email"

pages = ["account", "header", "config", "folder", "body"]
okPages = "|".join(pages)

usage = """Usage:
  %(exec)s [OPTS]

  OPTS:
    --page=[%(okPages)s]
      start on the indicated page
    --account=ACCOUNT_NAME
      default the account to ACCOUNT_NAME {only useful with --page}
    --folder=FOLDER_NAME
      default the folder to ACCOUNT_NAME {only useful with --page}
    --uid=UID
      default the message to UID {only useful with --page}
""" % {"exec": sys.argv[0], "okPages": okPages}

def main():
  args = sys.argv
  args.pop(0)

  opts = {}
  while len(args) > 0 and args[0].startswith("-"):
    arg = args.pop(0)
    pageMatch = re.match("^--page=(" + okPages + ")$", arg)
    accountMatch = re.match("^--account=(\\w+)$", arg)
    folderMatch = re.match("^--folder=(\\w+)$", arg)
    uidMatch = re.match("^--uid=(\\w+)$", arg)
    if pageMatch:
      opts['page'] = pageMatch.group(1)
    elif accountMatch:
      opts['account'] = accountMatch.group(1)
    elif folderMatch:
      opts['folder'] = folderMatch.group(1)
    elif uidMatch:
      opts['uid'] = uidMatch.group(1)
    else:
      print >> sys.stderr, usage
      sys.exit(2)
  if len(args) > 0:
    print >> sys.stderr, usage
    sys.exit(2)

  issue = open('/etc/issue').read().strip().lower()
  platform = None
  if "harmattan" in issue:
    platform = PLATFORM_HARMATTAN
  else:
    platform = PLATFORM_OTHER

  if platform == PLATFORM_HARMATTAN:
    qmlFile = "/opt/email-gui/harmattan.qml"
  else:
    qmlFile = "/opt/email-gui/desktop.qml"

  emailManager = EmailManager()
  accountModel = AccountModel()
  folderModel = FolderModel()
  headerModel = HeaderModel()
  configModel = ConfigModel()
  controller = Controller(emailManager, accountModel, folderModel, headerModel, configModel)

  if 'page' in opts:
    controller.setInitialPageName(opts['page'])
  if 'account' in opts:
    controller.setAccountName(opts['account'])
  if 'folder' in opts:
    controller.setFolderName(opts['folder'])
  if 'uid' in opts:
    controller.setUid(opts['uid'])

  app = QApplication([])
  widget = MainWindow(qmlFile, controller, accountModel, folderModel, headerModel, configModel)
  if platform == PLATFORM_HARMATTAN:
    widget.window().showFullScreen()
  else:
    widget.window().show()

  app.exec_()

class EmailManager():
  def readAccountConfig(self, accName):
    fieldNames = [ "name"
                 , "user"
                 , "password"
                 , "server"
                 , "sent"
                 , "port"
                 , "ssl"
                 , "smtp_server"
                 , "smtp_port"
                 ]

    config = {}
    if accName != None:
      configOut = self.readProc(["email.pl", "--read-config", accName])
      for line in configOut.splitlines():
        print line
        m = re.match("(\w+)=(.*)", line)
        if m:
          fieldName = m.group(1)
          value = m.group(2)
          print fieldName + " => " + value
          if fieldName in fieldNames:
            config[m.group(1)] = m.group(2)

    fields = []
    for fieldName in fieldNames:
      if fieldName in config:
        value = config[fieldName]
      else:
        value = ""
      fields.append(Field(fieldName, value))
    return fields
  def writeAccountConfig(self, fields):
    keyVals = []
    accName = None
    for field in fields:
      if field.FieldName == "name":
        accName = field.Value
      else:
        keyVals.append(field.FieldName + "=" + field.Value)

    cmd = ["email.pl", "--write-config", accName] + keyVals
    exitCode = subprocess.call(cmd)
  def getAccounts(self):
    accountOut = self.readProc(["email.pl", "--accounts"])
    accounts = []
    for line in accountOut.splitlines():
      m = re.match("(\w+):(\d+):([a-z0-9_\- ]+):(\d+)/(\d+):(.*)", line)
      if m:
        accName = m.group(1)
        lastUpdated = int(m.group(2))
        lastUpdatedRel = m.group(3)
        unreadCount = int(m.group(4))
        totalCount = int(m.group(5))
        error = m.group(6)
        accounts.append(Account(
          accName, lastUpdated, lastUpdatedRel, unreadCount, totalCount, error, False))
    return accounts
  def getFolders(self, accountName):
    folderOut = self.readProc(["email.pl", "--folders", accountName])
    folders = []
    for line in folderOut.splitlines():
      m = re.match("([a-z]+):(\d+)/(\d+)", line)
      if m:
        folderName = m.group(1)
        unreadCount = int(m.group(2))
        totalCount = int(m.group(3))
        folders.append(Folder(
          folderName, unreadCount, totalCount))
    return folders
  def getUids(self, accName, folderName, fileName):
    filePath = EMAIL_DIR + "/" + accName + "/" + folderName + "/" + fileName
    if not os.path.isfile(filePath):
      return []
    f = open(filePath, 'r')
    uids = f.read()
    f.close()
    return map(int, uids.splitlines())
  def fetchHeaders(self, accName, folderName, limit=None, exclude=[]):
    uids = self.getUids(accName, folderName, "all")
    uids.sort()
    uids.reverse()
    if len(exclude) > 0:
      exUids = set(map(lambda header: header.uid_, exclude))
      uids = filter(lambda uid: uid not in exUids, uids)
    if limit != None:
      uids = uids[0:limit]
    unread = set(self.getUids(accName, folderName, "unread"))
    headers = []
    for uid in uids:
      header = self.getHeader(accName, folderName, uid, not uid in unread)
      headers.append(header)
    return headers
  def getHeader(self, accName, folderName, uid, isRead):
    filePath = EMAIL_DIR + "/" + accName + "/" + folderName + "/" + "headers/" + str(uid)
    if not os.path.isfile(filePath):
      return None
    f = open(filePath, 'r')
    header = f.read()
    f.close()
    hdrDate = ""
    hdrFrom = ""
    hdrSubject = ""
    for line in header.splitlines():
      m = re.match('(\w+): (.*)', line)
      if not m:
        return None
      field = m.group(1)
      val = m.group(2)
      try:
        val = val.encode('utf-8')
      except:
        val = val.decode('utf-8')

      if field == "Date":
        hdrDate = val
      elif field == "From":
        hdrFrom = val
      elif field == "To":
        hdrTo = val
      elif field == "Subject":
        hdrSubject = val
    isSent = folderName == "sent"
    return Header(uid, hdrDate, hdrFrom, hdrTo, hdrSubject, isSent, isRead, False)
  def getBody(self, accName, folderName, uid):
    return self.readProc(["email.pl", "--body-html",
      "--folder=" + folderName, accName, str(uid)])
  def readProc(self, cmdArr):
    process = subprocess.Popen(cmdArr, stdout=subprocess.PIPE)
    (stdout, _) = process.communicate()
    return stdout

class Controller(QObject):
  def __init__(self, emailManager, accountModel, folderModel, headerModel, configModel):
    QObject.__init__(self)
    self.emailManager = emailManager
    self.accountModel = accountModel
    self.folderModel = folderModel
    self.headerModel = headerModel
    self.configModel = configModel
    self.initialPageName = "account"
    self.accountName = None
    self.folderName = None
    self.uid = None
    self.threads = []
    self.currentHeaders = []
    self.headerFilterRegex = None

  @Slot(QObject, str, result=QObject)
  def findChild(self, obj, name):
    return obj.findChild(QObject, name)

  @Slot()
  def setupAccounts(self):
    self.accountModel.setItems(self.emailManager.getAccounts())
  @Slot()
  def setupFolders(self):
    self.folderModel.setItems(self.emailManager.getFolders(self.accountName))
  @Slot()
  def setupHeaders(self):
    self.headerFilterRegex = None
    headers = self.emailManager.fetchHeaders(
      self.accountName, self.folderName,
      limit=PAGE_INITIAL_SIZE, exclude=[])
    self.setHeaders(headers)
  @Slot()
  def setupConfig(self):
    config = self
    fields = self.emailManager.readAccountConfig(self.accountName)
    self.configModel.setItems(fields)

  @Slot(QObject, str)
  def updateConfigFieldValue(self, field, value):
    field.value_ = value
  @Slot()
  def saveConfig(self):
    fields = self.configModel.getItems()
    self.emailManager.writeAccountConfig(fields)

  @Slot(QObject)
  def accountSelected(self, account):
    self.setAccountName(account.Name)
    self.setFolderName("inbox")
  @Slot(QObject)
  def folderSelected(self, folder):
    self.setFolderName(folder.Name)
  @Slot(QObject)
  def headerSelected(self, header):
    self.setUid(header.Uid)
  @Slot()
  def clearAccount(self):
    self.reset()

  @Slot(result=str)
  def getInitialPageName(self):
    return self.initialPageName
  def setInitialPageName(self, pageName):
    self.initialPageName = pageName

  def setAccountName(self, accName):
    self.accountName = accName
  def setFolderName(self, folderName):
    self.folderName = folderName
  def setUid(self, uid):
    self.uid = uid
  def reset(self):
    self.setAccountName(None)
    self.setFolderName(None)
    self.setUid(None)

  def filterHeader(self, header):
    return (self.headerFilterRegex == None
      or self.headerFilterRegex.search(header.subject_)
      or self.headerFilterRegex.search(header.from_)
      or self.headerFilterRegex.search(header.to_)
    )
  def setHeaderFilterRegex(self, regex):
    self.headerFilterRegex = regex
    self.setHeaders(self.currentHeaders)
  def setHeaders(self, headers):
    self.currentHeaders = headers
    filteredHeaders = filter(self.filterHeader, headers)
    if len(filteredHeaders) == 0:
      self.headerModel.clear()
    else:
      self.headerModel.setItems(filteredHeaders)
  def appendHeaders(self, headers):
    self.currentHeaders += headers
    filteredHeaders = filter(self.filterHeader, headers)
    print "\n\n\n\n" + str(len(filteredHeaders)) + "\n"
    if len(filteredHeaders) > 0:
      self.headerModel.appendItems(filteredHeaders)

  @Slot(str)
  def onSearchTextChanged(self, searchText):
    self.setHeaderFilterRegex(re.compile(searchText.strip(), re.IGNORECASE))

  @Slot(QObject, QObject, QObject)
  def updateAccount(self, updateIndicator, messageBox, account):
    if account == None:
      accMsg = "ALL ACCOUNTS"
    else:
      accMsg = account.Name
    self.onAppendMessage(messageBox, "STARTING UPDATE FOR " + accMsg + "\n")

    if account != None:
      account.isLoading_ = True
    if updateIndicator != None:
      updateIndicator.updateColor()

    thread = UpdateThread(updateIndicator, messageBox, account)
    thread.updateFinished.connect(self.onUpdateAccountFinished)
    thread.setMessage.connect(self.onSetMessage)
    thread.appendMessage.connect(self.onAppendMessage)
    self.startThread(thread)
  def onSetMessage(self, messageBox, message):
    messageBox.setText(message)
  def onAppendMessage(self, messageBox, message):
    messageBox.append(message)
    messageBox.scrollToBottom()
  def onUpdateAccountFinished(self, updateIndicator, account):
    self.setupAccounts()

  @Slot(QObject, QObject)
  def toggleRead(self, readIndicator, header):
    header.isLoading_ = True
    readIndicator.updateColor()

    thread = ToggleReadThread(readIndicator,
      self.accountName, self.folderName, header)
    thread.toggleReadFinished.connect(self.onToggleReadFinished)
    self.startThread(thread)
  def onToggleReadFinished(self, readIndicator, header, isRead):
    header.isLoading_ = False
    header.read_ = isRead
    readIndicator.updateColor()

  @Slot()
  def moreHeaders(self):
    headers = self.emailManager.fetchHeaders(
      self.accountName, self.folderName,
      limit=PAGE_MORE_SIZE, exclude=self.currentHeaders)
    self.appendHeaders(headers)

  @Slot(result=str)
  def getCurrentBodyText(self):
    if self.uid != None:
      return self.emailManager.getBody(
        self.accountName, self.folderName, self.uid)
    else:
      return "MISSING UID"

  def startThread(self, thread):
    self.threads.append(thread)
    thread.finished.connect(lambda: self.cleanupThread(thread))
    thread.start()
  def cleanupThread(self, thread):
    self.threads.remove(thread)

class UpdateThread(QThread):
  updateFinished = Signal(QObject, QObject)
  setMessage = Signal(QObject, str)
  appendMessage = Signal(QObject, str)
  def __init__(self, updateIndicator, messageBox, account):
    QThread.__init__(self)
    self.updateIndicator = updateIndicator
    self.messageBox = messageBox
    self.account = account
  def run(self):
    cmd = ["email.pl", "--update"]
    if self.account != None:
      cmd.append(self.account.Name)
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE)
    for line in iter(proc.stdout.readline,''):
      self.appendMessage.emit(self.messageBox, line)
    proc.wait()
    if proc.returncode == 0:
      self.appendMessage.emit(self.messageBox, "SUCCESS\n")
    else:
      self.appendMessage.emit(self.messageBox, "FAILURE\n")
    self.updateFinished.emit(self.updateIndicator, self.account)

class ToggleReadThread(QThread):
  toggleReadFinished = Signal(QObject, QObject, bool)
  def __init__(self, readIndicator, accountName, folderName, header):
    QThread.__init__(self)
    self.readIndicator = readIndicator
    self.accountName = accountName
    self.folderName = folderName
    self.header = header
  def run(self):
    wasRead = self.header.Read
    if wasRead:
      arg = "--mark-unread"
    else:
      arg = "--mark-read"
    cmd = ["email.pl", arg,
      "--folder=" + self.folderName, self.accountName, str(self.header.uid_)]
    exitCode = subprocess.call(cmd)
    if exitCode == 0:
      isRead = not wasRead
    else:
      isRead = wasRead
    self.toggleReadFinished.emit(self.readIndicator, self.header, isRead)

class BaseListModel(QAbstractListModel):
  def __init__(self):
    QAbstractListModel.__init__(self)
    self.items = []
  def getItems(self):
    return self.items
  def setItems(self, items):
    self.clear()
    self.beginInsertRows(QModelIndex(), 0, 0)
    self.items = items
    self.endInsertRows()
  def appendItems(self, items):
    self.beginInsertRows(QModelIndex(), len(self.items), len(self.items))
    self.items.extend(items)
    self.endInsertRows()
  def rowCount(self, parent=QModelIndex()):
    return len(self.items)
  def data(self, index, role):
    if role == Qt.DisplayRole:
      return self.items[index.row()]
  def clear(self):
    self.removeRows(0, len(self.items))
  def removeRows(self, firstRow, rowCount, parent = QModelIndex()):
    self.beginRemoveRows(parent, firstRow, firstRow+rowCount-1)
    while rowCount > 0:
      del self.items[firstRow]
      rowCount -= 1
    self.endRemoveRows()

class AccountModel(BaseListModel):
  COLUMNS = ('account',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(AccountModel.COLUMNS)))

class FolderModel(BaseListModel):
  COLUMNS = ('folder',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(FolderModel.COLUMNS)))

class HeaderModel(BaseListModel):
  COLUMNS = ('header',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(HeaderModel.COLUMNS)))

class ConfigModel(BaseListModel):
  COLUMNS = ('config',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(ConfigModel.COLUMNS)))

class Account(QObject):
  def __init__(self, name_, lastUpdated_, lastUpdatedRel_, unread_, total_, error_, isLoading_):
    QObject.__init__(self)
    self.name_ = name_
    self.lastUpdated_ = lastUpdated_
    self.lastUpdatedRel_ = lastUpdatedRel_
    self.unread_ = unread_
    self.total_ = total_
    self.error_ = error_
    self.isLoading_ = isLoading_
  def Name(self):
    return self.name_
  def LastUpdated(self):
    return self.lastUpdated_
  def LastUpdatedRel(self):
    return self.lastUpdatedRel_
  def Unread(self):
    return self.unread_
  def Total(self):
    return self.total_
  def Error(self):
    return self.error_
  def IsLoading(self):
    return self.isLoading_
  changed = Signal()
  Name = Property(unicode, Name, notify=changed)
  LastUpdated = Property(int, LastUpdated, notify=changed)
  LastUpdatedRel = Property(unicode, LastUpdatedRel, notify=changed)
  Unread = Property(int, Unread, notify=changed)
  Total = Property(int, Total, notify=changed)
  Error = Property(unicode, Error, notify=changed)
  IsLoading = Property(bool, IsLoading, notify=changed)

class Folder(QObject):
  def __init__(self, name_, unread_, total_):
    QObject.__init__(self)
    self.name_ = name_
    self.unread_ = unread_
    self.total_ = total_
  def Name(self):
    return self.name_
  def Unread(self):
    return self.unread_
  def Total(self):
    return self.total_
  changed = Signal()
  Name = Property(unicode, Name, notify=changed)
  Unread = Property(int, Unread, notify=changed)
  Total = Property(int, Total, notify=changed)

class Header(QObject):
  def __init__(self, uid_, date_, from_, to_, subject_, isSent_, read_, isLoading_):
    QObject.__init__(self)
    self.uid_ = uid_
    self.date_ = date_
    self.from_ = from_
    self.to_ = to_
    self.subject_ = subject_
    self.isSent_ = isSent_
    self.read_ = read_
    self.isLoading_ = isLoading_
  def Uid(self):
    return self.uid_
  def Date(self):
    return self.date_
  def From(self):
    return self.from_
  def To(self):
    return self.to_
  def Subject(self):
    return self.subject_
  def IsSent(self):
    return self.isSent_
  def Read(self):
    return self.read_
  def IsLoading(self):
    return self.isLoading_
  changed = Signal()
  Uid = Property(int, Uid, notify=changed)
  Date = Property(unicode, Date, notify=changed)
  From = Property(unicode, From, notify=changed)
  To = Property(unicode, To, notify=changed)
  Subject = Property(unicode, Subject, notify=changed)
  IsSent = Property(bool, IsSent, notify=changed)
  Read = Property(bool, Read, notify=changed)
  IsLoading = Property(bool, IsLoading, notify=changed)

class Field(QObject):
  def __init__(self, fieldName_, value_):
    QObject.__init__(self)
    self.fieldName_ = fieldName_
    self.value_ = value_
  def FieldName(self):
    return self.fieldName_
  def Value(self):
    return self.value_
  changed = Signal()
  FieldName = Property(unicode, FieldName, notify=changed)
  Value = Property(unicode, Value, notify=changed)

class MainWindow(QDeclarativeView):
  def __init__(self, qmlFile, controller, accountModel, folderModel, headerModel, configModel):
    super(MainWindow, self).__init__(None)
    context = self.rootContext()
    context.setContextProperty('accountModel', accountModel)
    context.setContextProperty('folderModel', folderModel)
    context.setContextProperty('headerModel', headerModel)
    context.setContextProperty('configModel', configModel)
    context.setContextProperty('controller', controller)
    self.setResizeMode(QDeclarativeView.SizeRootObjectToView)
    self.setSource(qmlFile)

if __name__ == "__main__":
  sys.exit(main())
