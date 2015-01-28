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

PAGE_INITIAL_SIZE = 50
PAGE_MORE_SIZE = 50

UNREAD_COUNTS = os.getenv("HOME") + "/.unread-counts"
EMAIL_DIR = os.getenv("HOME") + "/.cache/email"

def main():
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
  headerModel = HeaderModel()
  controller = Controller(emailManager, accountModel, headerModel)

  controller.setupAccounts()

  app = QApplication([])
  widget = MainWindow(qmlFile, controller, accountModel, headerModel)
  if platform == PLATFORM_HARMATTAN:
    widget.window().showFullScreen()
  else:
    widget.window().show()

  app.exec_()

class EmailManager():
  def getAccounts(self):
    if not os.path.isfile(UNREAD_COUNTS):
      return []
    f = open(UNREAD_COUNTS, 'r')
    counts = f.read()
    f.close()
    accounts = []
    for line in counts.splitlines():
      m = re.match('^(\d+):(\w+)', line)
      if not m:
        return []
      accounts.append(Account(m.group(2), int(m.group(1))))
    return accounts
  def getUids(self, accName, fileName):
    filePath = EMAIL_DIR + "/" + accName + "/" + fileName
    if not os.path.isfile(filePath):
      return []
    f = open(filePath, 'r')
    uids = f.read()
    f.close()
    return map(int, uids.splitlines())
  def fetchHeaders(self, accName, limit=None, exclude=[]):
    uids = self.getUids(accName, "all")
    uids.sort()
    uids.reverse()
    if len(exclude) > 0:
      exUids = set(map(lambda header: header.uid_, exclude))
      uids = filter(lambda uid: uid not in exUids, uids)
    if limit != None:
      uids = uids[0:limit]
    unread = set(self.getUids(accName, "unread"))
    return map(lambda uid: self.getHeader(accName, uid, not uid in unread), uids)
  def getHeader(self, accName, uid, isRead):
    filePath = EMAIL_DIR + "/" + accName + "/" + "headers/" + str(uid)
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
      elif field == "Subject":
        hdrSubject = val
    return Header(uid, hdrDate, hdrFrom, hdrSubject, isRead, False)
  def getBody(self, accName, uid):
    return self.readProc(["email.pl", "--body-html", accName, str(uid)])
  def readProc(self, cmdArr):
    process = subprocess.Popen(cmdArr, stdout=subprocess.PIPE)
    (stdout, _) = process.communicate()
    return stdout

class Controller(QObject):
  def __init__(self, emailManager, accountModel, headerModel):
    QObject.__init__(self)
    self.emailManager = emailManager
    self.accountModel = accountModel
    self.headerModel = headerModel
    self.currentAccount = None
    self.threads = []
  @Slot()
  def setupAccounts(self):
    self.accountModel.setItems(self.emailManager.getAccounts())
  @Slot(QObject)
  def accountSelected(self, account):
    print 'clicked acc: ', account.Name
    self.currentAccount = account.Name
    headers = self.emailManager.fetchHeaders(self.currentAccount,
      limit=PAGE_INITIAL_SIZE, exclude=[])
    self.headerModel.setItems(headers)
  @Slot(QObject, QObject)
  def toggleRead(self, readIndicator, header):
    thread = ToggleReadThread(readIndicator, self.currentAccount, header)
    self.startThread(thread)
  @Slot()
  def moreHeaders(self):
    headers = self.emailManager.fetchHeaders(self.currentAccount,
      limit=PAGE_MORE_SIZE, exclude=self.headerModel.getItems())
    self.headerModel.appendItems(headers)
  @Slot(QObject, result=str)
  def getBodyText(self, header):
    print 'clicked uid:', str(header.uid_)
    return self.emailManager.getBody(self.currentAccount, header.uid_)
  def startThread(self, thread):
    self.threads.append(thread)
    thread.finished.connect(lambda: self.cleanupThread(thread))
    thread.start()
  def cleanupThread(self, thread):
    self.threads.remove(thread)

class ToggleReadThread(QThread):
  def __init__(self, readIndicator, account, header):
    QThread.__init__(self)
    self.readIndicator = readIndicator
    self.account = account
    self.header = header
  def run(self):
    wasRead = self.header.Read
    if wasRead:
      arg = "--mark-unread"
    else:
      arg = "--mark-read"
    cmd = ["email.pl", arg, self.account, str(self.header.uid_)]
    exitCode = subprocess.call(cmd)
    if exitCode == 0:
      isRead = not wasRead
    else:
      isRead = wasRead

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

class HeaderModel(BaseListModel):
  COLUMNS = ('header',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(HeaderModel.COLUMNS)))

class Account(QObject):
  def __init__(self, name_, unread_):
    QObject.__init__(self)
    self.name_ = name_
    self.unread_ = unread_
  def Name(self):
    return self.name_
  def Unread(self):
    return self.unread_
  changed = Signal()
  Name = Property(unicode, Name, notify=changed)
  Unread = Property(int, Unread, notify=changed)

class Header(QObject):
  def __init__(self, uid_, date_, from_, subject_, read_, isLoading_):
    QObject.__init__(self)
    self.uid_ = uid_
    self.date_ = date_
    self.from_ = from_
    self.subject_ = subject_
    self.read_ = read_
    self.isLoading_ = isLoading_
  def Uid(self):
    return self.uid_
  def Date(self):
    return self.date_
  def From(self):
    return self.from_
  def Subject(self):
    return self.subject_
  def Read(self):
    return self.read_
  def IsLoading(self):
    return self.isLoading_
  changed = Signal()
  Uid = Property(int, Uid, notify=changed)
  Date = Property(unicode, Date, notify=changed)
  From = Property(unicode, From, notify=changed)
  Subject = Property(unicode, Subject, notify=changed)
  Read = Property(bool, Read, notify=changed)
  IsLoading = Property(bool, IsLoading, notify=changed)

class MainWindow(QDeclarativeView):
  def __init__(self, qmlFile, controller, accountModel, headerModel):
    super(MainWindow, self).__init__(None)
    context = self.rootContext()
    context.setContextProperty('accountModel', accountModel)
    context.setContextProperty('headerModel', headerModel)
    context.setContextProperty('controller', controller)
    self.setResizeMode(QDeclarativeView.SizeRootObjectToView)
    self.setSource(qmlFile)

if __name__ == "__main__":
  sys.exit(main())
