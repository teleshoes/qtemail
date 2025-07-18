#!/usr/bin/python
#QtEmail email-gui.py
#Copyright 2012,2015,2020 Elliot Wolk
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

from PyQt5.QtGui import *
from PyQt5.QtCore import *
from PyQt5.QtQuick import *
from PyQt5.QtWidgets import *

import os
import os.path
import re
import signal
import sys
import subprocess
import time

EMAIL_BIN = "/opt/qtemail/bin/email.pl"
EMAIL_SEARCH_BIN = "/opt/qtemail/bin/email-search.pl"
QML_DIR = "/opt/qtemail/qml"

PLATFORM_DESKTOP = "desktop"
PLATFORM_MOBILE = "mobile"

PLATFORM_MOBILE_ISSUE_KEYWORDS = ["maemo", "mer", "sailfish"]

signal.signal(signal.SIGINT, signal.SIG_DFL)

PAGE_INITIAL_SIZE = 600
PAGE_INITIAL_WITHOUT_UNREAD_SIZE = 200
PAGE_MORE_SIZE = 200

EMAIL_DIR = os.getenv("HOME") + "/.cache/email"
CONFIG_DIR = os.getenv("HOME") + "/.config/qtemail"

PYTHON2 = sys.version_info < (3, 0)
PYTHON3 = sys.version_info >= (3, 0)

STR_TYPE = unicode if PYTHON2 else str

pages = ["account", "header", "config", "send", "folder", "body"]
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
    --desktop
      override /etc/issue detection and use desktop platform
    --mobile
      override /etc/issue detection and use mobile platform
    --font-scale=FONT_SCALE
      in addition to pixel density scaling, apply FONT_SCALE to all fonts
""" % {"exec": sys.argv[0], "okPages": okPages}

def warn(msg):
  sys.stderr.write(msg)
def die(msg):
  warn(msg)
  sys.exit(1)

def main():
  args = sys.argv
  args.pop(0)

  opts = {}
  platform = None
  while len(args) > 0 and args[0].startswith("-"):
    arg = args.pop(0)
    pageMatch = regexMatch("^--page=(" + okPages + ")$", arg)
    accountMatch = regexMatch("^--account=(\\w+)$", arg)
    folderMatch = regexMatch("^--folder=(\\w+)$", arg)
    uidMatch = regexMatch("^--uid=(\\w+)$", arg)
    desktopMatch = regexMatch("^--desktop$", arg)
    mobileMatch = regexMatch("^--mobile$", arg)
    fontScaleMatch = regexMatch("^--font-scale=(\\d+|\\d*\\.\\d+)", arg)
    if pageMatch:
      opts['page'] = pageMatch.group(1)
    elif accountMatch:
      opts['account'] = accountMatch.group(1)
    elif folderMatch:
      opts['folder'] = folderMatch.group(1)
    elif uidMatch:
      opts['uid'] = uidMatch.group(1)
    elif desktopMatch:
      platform = PLATFORM_DESKTOP
    elif mobileMatch:
      platform = PLATFORM_MOBILE
    elif fontScaleMatch:
      opts['fontScale'] = float(fontScaleMatch.group(1))
    else:
      die(usage)
  if len(args) > 0:
    die(usage)

  if platform == None:
    issue = open('/etc/issue').read().strip().lower()
    for keyword in PLATFORM_MOBILE_ISSUE_KEYWORDS:
      if keyword in issue:
        platform = PLATFORM_MOBILE
        break

  if platform == None:
    platform = PLATFORM_DESKTOP

  qmlFile = None
  useSendWindow = None

  if platform == PLATFORM_DESKTOP:
    qmlFile = QML_DIR + "/desktop.qml"
    useSendWindow = True
  elif platform == PLATFORM_MOBILE:
    qmlFile = QML_DIR + "/mobile.qml"
    useSendWindow = False
  else:
    die("unknown plaform: " + platform)

  emailManager = EmailManager()
  accountModel = AccountModel()
  folderModel = FolderModel()
  headerModel = HeaderModel()
  configModel = ConfigModel()
  notifierModel = NotifierModel()
  filterButtonModel = FilterButtonModel()
  addressBookModel = AddressBookModel()
  fileListModel = FileListModel()
  fileInfoModel = FileInfoModel()
  controller = Controller(emailManager,
    accountModel, folderModel, headerModel, configModel, filterButtonModel, notifierModel,
    addressBookModel, fileListModel, fileInfoModel)

  controller.setupAccounts()

  showSendWindowAtStart = False

  if 'page' in opts:
    if useSendWindow and opts['page'] == 'send':
      showSendWindowAtStart = True
    else:
      controller.setInitialPageName(opts['page'])
  if 'account' in opts:
    controller.accountSelected(opts['account'])
  if 'folder' in opts:
    controller.setFolderName(opts['folder'])
  if 'uid' in opts:
    hdr = emailManager.getHeader(opts['account'], opts['folder'], opts['uid'])
    controller.setHeader(hdr)

  if 'account' in opts or 'folder' in opts:
    controller.setupHeaders()

  if 'fontScale' in opts:
    controller.setFontScale(opts['fontScale'])

  app = QApplication([])
  mainWindow = MainWindow(qmlFile, controller,
    accountModel, folderModel, headerModel, configModel, filterButtonModel, notifierModel,
    addressBookModel, fileListModel, fileInfoModel)

  mainWindow.setTitle(os.path.basename(__file__))

  if useSendWindow:
    sendWindow = SendWindow(QML_DIR + "/SendView.qml", controller, mainWindow,
      accountModel, folderModel, headerModel, configModel, filterButtonModel, notifierModel,
      addressBookModel, fileListModel, fileInfoModel)
    sendView = sendWindow.rootObject()
    mainWindow.rootContext().setContextProperty('sendView', sendView)
    sendView.setNotifierEnabled(True)

    controller.setSendWindow(sendWindow)
    if showSendWindowAtStart:
      sendWindow.show()

  mainWindow.show()

  app.exec_()

class EmailManager():
  def __init__(self):
    self.emailRegex = self.compileEmailRegex()

  def compileEmailRegex(self):
    c = "[a-zA-Z0-9!#$%&'*+\\-/=?^_`{|}~]"
    start = c + "+"
    middleDot = "(?:" + "\\." + c + "+)*"
    end = c + "*"
    user = start + middleDot + end

    sub = "[a-zA-Z0-9\\-.]+"
    top = "[a-zA-Z]{2,}"
    host = sub + "\\." + top

    return re.compile(user + "@" + host)

  def parseEmails(self, string):
    if string == None:
      return []
    return self.emailRegex.findall(string)

  def readConfig(self, configMode, accName=None):
    configValues = {}
    cmd = [EMAIL_BIN]
    if configMode == "account":
      cmd.append("--read-config")
      if accName != None:
        cmd.append(accName)
    elif configMode == "options":
      cmd.append("--read-options")
    else:
      die("invalid config mode: " + configMode)

    if cmd != None:
      configOut = self.readProc(cmd)

      for line in configOut.splitlines():
        m = regexMatch(r"(\w+(?:\.\w+)?)=(.*)", line)
        if m:
          fieldName = m.group(1)
          value = m.group(2)
          value = value.replace('\\n', '\n')
          configValues[fieldName] = value
    return configValues
  def writeConfig(self, configValues, configMode, accName=None):
    cmd = [EMAIL_BIN]
    if configMode == "account":
      cmd.append("--write-config")
      cmd.append(accName)
    elif configMode == "options":
      cmd.append("--write-options")
    else:
      die("invalid config mode: " + str(configMode))

    for key in configValues.keys():
      cmd.append(key + "=" + configValues[key])

    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out, err) = process.communicate()
    print >> sys.stdout, out
    print >> sys.stderr, err
    return {'exitCode': process.returncode, 'stdout': out, 'stderr': err}
  def readSchema(self, configMode):
    cmd = [EMAIL_BIN]
    if configMode == "account":
      cmd.append("--read-config-schema")
    elif configMode == "options":
      cmd.append("--read-options-schema")
    else:
      die("invalid config mode: " + str(configMode))

    process = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    (out, err) = process.communicate()
    print >> sys.stderr, err

    schema = []
    for line in out.splitlines():
      m = regexMatch(r"(\w+)\s*=\s*(.+)", line)
      if m:
        key = m.group(1)
        desc = m.group(2)
        schema.append((key, desc))
    return schema

  def getConfigFields(self, schema, configValues):
    fieldNames = list(map(lambda k,v: k, schema))
    fieldDescriptions = dict(schema)

    fields = []
    for fieldName in fieldNames:
      if fieldName in configValues:
        value = configValues[fieldName]
      else:
        value = ""
      pwRegex = re.compile('password|pword|^pw$', re.IGNORECASE)
      isPass = pwRegex.search(fieldName) != None
      fields.append(Field(fieldName, isPass, value, fieldDescriptions[fieldName]))
    return fields

  def getAccountConfigFields(self, accName):
    schema = self.readSchema("account")
    schema = [("name", "single-word account ID, e.g.: \"Work\"")] + schema

    if accName == None:
      configValues = []
    else:
      configValues = self.readConfig("account", accName)
    return self.getConfigFields(schema, configValues)
  def getOptionsConfigFields(self):
    schema = self.readSchema("options")

    configValues = self.readConfig("options")
    return self.getConfigFields(schema, configValues)

  def saveAccountConfigFields(self, fields):
    configValues = {}
    accName = None
    for field in fields:
      if field.FieldName == "name":
        accName = field.Value
      else:
        configValues[field.FieldName] = field.Value
    return self.writeConfig(configValues, "account", accName)
  def saveOptionsConfigFields(self, fields):
    configValues = {}
    for field in fields:
      configValues[field.FieldName] = field.Value
    return self.writeConfig(configValues, "options")

  def getAccounts(self):
    accountOut = self.readProc([EMAIL_BIN, "--accounts"])
    accounts = []
    for line in accountOut.splitlines():
      m = regexMatch(r"(\w+):(\d+):([a-z0-9_\- ]+):(\d+)s:(\d+)s:(\d+)/(\d+):(.*)", line)
      if m:
        accName = m.group(1)
        lastUpdated = int(m.group(2))
        lastUpdatedRel = m.group(3)
        updateInterval = int(m.group(4))
        refreshInterval = int(m.group(5))
        unreadCount = int(m.group(6))
        totalCount = int(m.group(7))
        error = m.group(8)
        accounts.append(Account(
          accName, lastUpdated, lastUpdatedRel, updateInterval, refreshInterval, unreadCount, totalCount, error, False))
    return accounts
  def getFolders(self, accountName):
    if accountName == None:
      return []

    folderOut = self.readProc([EMAIL_BIN, "--folders", accountName])
    folders = []
    for line in folderOut.splitlines():
      m = regexMatch(r"([a-zA-Z_]+):(\d+)/(\d+)", line)
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
    uids = f.read().splitlines()
    f.close()
    uids = filter(lambda uid: re.match(r"^\d+$", uid), uids)
    return list(map(int, uids))
  def fetchHeaders(self, accName, folderName, limit=None, limitWithoutUnread=None, exclude=[], minUid=None):
    uids = self.getUids(accName, folderName, "all")
    uids.sort()
    uids.reverse()
    total = len(uids)
    unread = set(self.getUids(accName, folderName, "unread"))

    if minUid != None:
      uids = list(filter(lambda uid: uid >= minUid, uids))
    if len(exclude) > 0:
      exUids = set(map(lambda header: header.uid_, exclude))
      uids = list(filter(lambda uid: uid not in exUids, uids))
    if limit != None:
      uids = uids[0:limit]
    if limitWithoutUnread != None:
      while len(uids) > limitWithoutUnread and uids[-1] not in unread:
        uids.pop()

    headers = []
    for uid in uids:
      header = self.getHeader(accName, folderName, uid)
      header.isSent_ = folderName == "sent"
      header.read_ = not uid in unread
      headers.append(header)
    return (total, headers)
  def getHeader(self, accName, folderName, uid):
    filePath = EMAIL_DIR + "/" + accName + "/" + folderName + "/" + "headers/" + str(uid)
    if not os.path.isfile(filePath):
      print("MISSING EMAIL HEADER: " + filePath)
      return None
    f = open(filePath, 'r')
    header = f.read()
    f.close()
    hdrDate = ""
    hdrFrom = ""
    hdrTo = ""
    hdrCC = ""
    hdrBCC = ""
    hdrSubject = ""
    for line in header.split('\n'):
      if line.strip() == "":
        continue
      m = regexMatch(r'(\w+): (.*)', line)
      if not m:
        print("MALFORMED HEADER FILE: " + filePath)
        return None
      field = m.group(1)
      val = m.group(2)
      if PYTHON2:
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
      elif field == "CC":
        hdrCC = val
      elif field == "BCC":
        hdrBCC = val
      elif field == "Subject":
        hdrSubject = val
    return Header(uid, hdrDate, hdrFrom, hdrTo, hdrCC, hdrBCC, hdrSubject, False, False, False)
  def getCachedBodies(self, accountName, folderName, uids, isHtml):
    if isHtml:
      bodyArg = "--body-html"
    else:
      bodyArg = "--body-plain"
    cmd = [EMAIL_BIN, bodyArg, "--no-download", "-0",
      "--folder=" + folderName, accountName] + list(map(str,uids))
    bodyNuls = self.readProc(cmd)
    bodies = bodyNuls.split("\0")
    if len(bodies) > 0 and bodies[-1] == "":
      bodies.pop()
    if len(bodies) != len(uids):
      raise Exception("ERROR: could not read bodies")
    uidBodies = dict(zip(uids, bodies))
    for uid in uidBodies.keys():
      body = uidBodies[uid]
      try:
        body = body.encode('utf-8')
      except:
        try:
          body = body.decode('utf-8')
        except:
          body = regexSub(r'[^\x00-\x7F]', ' ', body).encode('utf-8')
    return uidBodies
  def getAddressBook(self):
    filePath = CONFIG_DIR + "/" + "addressbook"
    if not os.path.isfile(filePath):
      return []
    f = open(filePath, 'r')
    addressBookContents = f.read()
    f.close()
    commentRegex = re.compile("^\\s*#|^\\s*$")
    accNameRegex = re.compile("^\\s*=\\s*(\\w+)\\s*=\\s*$")
    addressBook = dict()
    curAccName = None
    for line in addressBookContents.splitlines():
      if regexMatch(commentRegex, line):
        continue
      accNameMatcher = regexMatch(accNameRegex, line)
      if accNameMatcher:
        curAccName = accNameMatcher.group(1)
      else:
        if curAccName == None:
          warn("error reading address book, missing account name\n")
          return []
        if curAccName not in addressBook:
          addressBook[curAccName] = []
        addressBook[curAccName].append(line)
    return addressBook

  def readProc(self, cmdArr):
    process = subprocess.Popen(cmdArr, stdout=subprocess.PIPE)
    (stdout, _) = process.communicate()
    return stdout

class Controller(QObject):
  def __init__(self, emailManager,
    accountModel, folderModel, headerModel, configModel, filterButtonModel, notifierModel,
    addressBookModel, fileListModel, fileInfoModel):
    QObject.__init__(self)
    self.fontScale = 1.0
    self.emailManager = emailManager
    self.accountModel = accountModel
    self.folderModel = folderModel
    self.headerModel = headerModel
    self.configModel = configModel
    self.filterButtonModel = filterButtonModel
    self.notifierModel = notifierModel
    self.addressBookModel = addressBookModel
    self.fileListModel = fileListModel
    self.fileInfoModel = fileInfoModel
    self.initialPageName = "account"
    self.htmlMode = False
    self.configMode = None
    self.accountName = None
    self.accountConfig = None
    self.folderName = None
    self.header = None
    self.currentBodyText = None
    self.threads = []
    self.currentHeaders = []
    self.headerFilters = []
    self.filterButtons = []
    self.setFilterButtons([])
    self.addressBook = None
    self.sendWindow = None
    self.counterBox = None
    self.fileListDir = None

  @pyqtSlot(result=float)
  def getFontScale(self):
    return self.fontScale
  def setFontScale(self, fontScale):
    self.fontScale = fontScale

  @pyqtSlot(result=str)
  def getHomeDir(self):
    return os.getenv("HOME")

  @pyqtSlot(str)
  def addFileInfo(self, filePath):
    sizeFmt = ""
    mtimeFmt = ""
    error = ""
    try:
      if not os.path.exists(filePath):
        error = 'ERROR: could not find file'
      elif os.path.isdir(filePath):
        error = 'ERROR: file is directory'
      else:
        stat = os.stat(filePath)
        sizeKiB = int(stat.st_size / 1024.0 + 0.5)
        mtime = stat.st_mtime

        sizeFmt = str(sizeKiB) + "KiB"
        mtimeFmt = time.ctime(mtime)
    except:
      error = 'ERROR: unknown failure, could not stat file'
    isDupe = False
    for fileInfo in self.fileInfoModel.getItems():
      if fileInfo.FilePath == filePath:
        print("skipping duplicate file: " + str(filePath))
        isDupe = True
    if not isDupe:
      self.fileInfoModel.appendItems([FileInfo(filePath, sizeFmt, mtimeFmt, error)])

  @pyqtSlot(str)
  def removeFileInfo(self, filePath):
    files = []
    for fileInfo in self.fileInfoModel.getItems():
      if fileInfo.FilePath == filePath:
        print("removing " + str(filePath))
      else:
        files.append(fileInfo)
    self.fileInfoModel.setItems(files)

  @pyqtSlot(str)
  def clearFileInfo(self):
    self.fileInfoModel.clear()

  @pyqtSlot(QObject)
  def setCounterBox(self, counterBox):
    self.counterBox = counterBox

  def setSendWindow(self, sendWindow):
    self.sendWindow = sendWindow

  @pyqtSlot()
  def showSendWindow(self):
    self.sendWindow.show()

  @pyqtSlot()
  def runCustomCommand(self):
    if self.accountConfig != None and "custom_cmd" in self.accountConfig.keys():
      cmd = ""
      if self.accountName != None:
        cmd += "QTEMAIL_ACCOUNT_NAME=\"" + self.accountName + "\"; \\\n"
      if self.folderName != None:
        cmd += "QTEMAIL_FOLDER_NAME=\"" + self.folderName + "\"; \\\n"
      if self.header != None:
        cmd += "QTEMAIL_UID=\"" + str(self.header.Uid) + "\"; \\\n"
      cmd += self.accountConfig["custom_cmd"]
      print("running command:\n" + cmd)
      self.shellCommand(cmd)
    else:
      print("no command to run\n")

  @pyqtSlot('QVariantList')
  def runCommand(self, cmdArr):
    subprocess.Popen(cmdArr)
  @pyqtSlot(str)
  def shellCommand(self, cmdStr):
    subprocess.Popen(['sh', '-c', cmdStr])

  @pyqtSlot(QObject, str, result=QObject)
  def findChild(self, obj, name):
    return obj.findChild(QObject, name)

  @pyqtSlot(str, QObject)
  def initSend(self, sendType, sendForm):
    if self.accountName == None or self.folderName == None or self.header == None:
      self.notifierModel.notify("Missing source email for " + sendType)
      return

    header = self.emailManager.getHeader(self.accountName, self.folderName, self.header.Uid)
    if header == None:
      self.notifierModel.notify("Could not parse headers for message")
      return

    toEmails = self.emailManager.parseEmails(header.To)
    fromEmails = self.emailManager.parseEmails(header.From)
    ccEmails = self.emailManager.parseEmails(header.CC)
    #do not retain bccEmails in reply/forward

    if sendType == "reply":
      if self.folderName == "sent":
        recipEmails = toEmails
      else:
        recipEmails = fromEmails
    else:
      recipEmails = []

    subjectPrefix = ""
    if sendType == "reply":
      subjectPrefix = "Re: "
    elif sendType == "forward":
      subjectPrefix = "Fwd: "
    subject = header.Subject
    if not subject.startswith(subjectPrefix):
      subject = subjectPrefix + subject

    if len(fromEmails) > 0:
      firstFrom = fromEmails[0]
    else:
      firstFrom = "[unknown]"

    date = header.Date

    sendForm.setTo(recipEmails)
    sendForm.setCC(ccEmails)
    sendForm.setBCC([]) #do not retain bccEmails in reply/forward
    sendForm.setSubject(subject)

    self.fetchCurrentBodyTextWithTransform(sendForm, None,
      lambda body: self.wrapBody(body, date, firstFrom), True)

  def wrapBody(self, body, date, author):
    bodyPrefix = "\n\nOn " + date + ", " + author + " wrote:\n"
    lines = [""] + body.splitlines()
    indentedBody = "\n".join(map(lambda line: "> " + line, lines)) + "\n"
    return bodyPrefix + indentedBody

  @pyqtSlot(str, result=bool)
  def updateFileList(self, text):
    oldDir = self.fileListDir
    self.fileListDir = self.extractDir(text)
    if oldDir == self.fileListDir:
      print("filelist: skipping, same dir '" + str(self.fileListDir) + "'")
      return False
    else:
      items = []
      if self.fileListDir != None:
        for f in self.listDir(self.fileListDir):
          items.append(Suggestion(f, self))

      if len(items) == 0:
        if len(self.fileListModel.getItems()) == 0:
          print("filelist: skipping, suggestions empty now and were empty")
          return False
        else:
          print("filelist: clearing")
          self.fileListModel.clear()
          return False
      else:
        print("filelist: adding " + str(len(items)) + " items")
        self.fileListModel.setItems(items)
        return True
  def extractDir(self, filePath):
    try:
      dirPath = os.path.dirname(filePath)
      if os.path.isdir(filePath):
        return filePath
      elif os.path.isdir(dirPath):
        return dirPath
      else:
        return None
    except:
      print("FAILED TO EXTRACT DIR: " + path)
      return None
  def listDir(self, dirPath):
    try:
      dirs = []
      files = []
      ls = os.listdir(dirPath)
      ls.sort()
      for f in ls:
        path = os.path.join(dirPath, f)
        if os.path.isdir(path):
          dirs.append(path + os.sep)
        else:
          files.append(path)
      return dirs + files
    except:
      print("FAILED TO LIST DIR: " + path)
      return None

  @pyqtSlot(QObject)
  def sendEmail(self, sendForm):
    to = listModelToArray(sendForm.getToModel())
    cc = listModelToArray(sendForm.getCCModel())
    bcc = listModelToArray(sendForm.getBCCModel())
    subject = sendForm.getSubject()
    body = sendForm.getBody()

    attachments = []
    attFilePaths = listModelToArray(sendForm.getAttachmentsModel())
    for attFilePath in attFilePaths:
      attachments.append(attFilePath.FilePath)

    if len(to) == 0:
      self.notifierModel.notify("TO is empty\n")
      return
    if self.accountName == None:
      self.notifierModel.notify("no FROM account selected\n")
      return
    firstTo = to.pop(0)

    self.notifierModel.notify("sending...", False)
    cmd = [EMAIL_BIN, "--smtp", self.accountName, subject, body, firstTo]
    for email in to:
      cmd += ["--to", email]
    for email in cc:
      cmd += ["--cc", email]
    for email in bcc:
      cmd += ["--bcc", email]
    for att in attachments:
      cmd += ["--attach", att]

    self.startEmailCommandThread(cmd, None,
      self.onSendEmailFinished, {})
  def onSendEmailFinished(self, isSuccess, output, extraArgs):
    if not isSuccess:
      self.notifierModel.notify("\nFAILED\n\n" + output, False)
    else:
      self.notifierModel.notify("\nSUCCESS\n\n" + output, False)

  @pyqtSlot()
  def setupAccounts(self):
    self.accountModel.setItems(self.emailManager.getAccounts())
    self.ensureAccountModelSelected()
  @pyqtSlot()
  def refreshAccountLabels(self):
    labels = self.accountModel.getItems()
    accs = self.emailManager.getAccounts()
    for label in labels:
      for acc in accs:
        if acc.Name == label.Name:
          label.refresh(
            acc.LastUpdated,
            acc.LastUpdatedRel,
            acc.UpdateInterval,
            acc.RefreshInterval,
            acc.Unread,
            acc.Total,
            acc.Error)
  @pyqtSlot()
  def setupFolders(self):
    self.folderModel.setItems(self.emailManager.getFolders(self.accountName))
  @pyqtSlot()
  def setupHeaders(self):
    self.headerFilters = []
    (total, headers) = self.emailManager.fetchHeaders(
      self.accountName, self.folderName,
      limit=PAGE_INITIAL_SIZE, limitWithoutUnread=PAGE_INITIAL_WITHOUT_UNREAD_SIZE,
      exclude=[], minUid=None)
    self.totalSize = total
    self.setHeaders(headers)
  @pyqtSlot(str)
  def setConfigMode(self, mode):
    self.configMode = mode
  @pyqtSlot()
  def setupConfig(self):
    if self.configMode == "account":
      self.setupAccountConfig()
    elif self.configMode == "options":
      self.setupOptionsConfig()
  def setupAccountConfig(self):
    fields = self.emailManager.getAccountConfigFields(self.accountName)
    self.configModel.setItems(fields)
  def setupOptionsConfig(self):
    fields = self.emailManager.getOptionsConfigFields()
    self.configModel.setItems(fields)

  @pyqtSlot(QObject, str)
  def updateConfigFieldValue(self, field, value):
    field.value_ = value

  @pyqtSlot(result=bool)
  def saveConfig(self):
    fields = self.configModel.getItems()
    if self.configMode == "account":
      res = self.emailManager.saveAccountConfigFields(fields)
    elif self.configMode == "options":
      res = self.emailManager.saveOptionsConfigFields(fields)

    if res['exitCode'] == 0:
      self.notifierModel.notify("saved config\n" + res['stdout'] + res['stderr'])
      return True
    else:
      self.notifierModel.notify("FAILURE\n" + res['stdout'] + res['stderr'])
      return False

  @pyqtSlot(str)
  def accountSelected(self, accountName):
    self.setAccountName(accountName)
    self.setFolderName("inbox")
    self.setAccountConfig(self.emailManager.readConfig("account", accountName))
    self.setupFolders()
    self.ensureAccountModelSelected()
    self.ensureAddressBook()
    self.resetFilterButtons()
  @pyqtSlot(QObject)
  def folderSelected(self, folder):
    self.setFolderName(folder.Name)
  @pyqtSlot(QObject)
  def headerSelected(self, header):
    self.setHeader(header)
  @pyqtSlot()
  def clearAccount(self):
    self.reset()

  def ensureAccountModelSelected(self):
    for account in self.accountModel.getItems():
      account.setSelected(account.Name == self.accountName)

  def ensureAddressBook(self):
    if self.addressBook == None:
      self.addressBook = self.emailManager.getAddressBook()

    if self.addressBook != None and self.accountName in self.addressBook:
      accEmails = self.addressBook[self.accountName]
    else:
      accEmails = None

    if accEmails == None or len(accEmails) == 0:
      self.addressBookModel.clear()
    else:
      items = []
      for emailAddress in accEmails:
        items.append(Suggestion(emailAddress, self))
      self.addressBookModel.setItems(items)

  @pyqtSlot(str, result=str)
  def getAccountConfigValue(self, configKey):
    if self.accountConfig != None and configKey in self.accountConfig:
      return self.accountConfig[configKey]
    return ''

  @pyqtSlot(result=str)
  def getInitialPageName(self):
    return self.initialPageName
  def setInitialPageName(self, pageName):
    self.initialPageName = pageName

  def setAccountName(self, accName):
    self.accountName = accName
    self.accountNameChanged.emit()
  def setFolderName(self, folderName):
    self.folderName = folderName
  def setHeader(self, header):
    if self.header != None:
      self.header.setSelected(False)
    self.header = header
    if self.header != None:
      self.header.setSelected(True)
  def setAccountConfig(self, accountConfig):
    self.accountConfig = accountConfig

    filterButtons = []
    if self.accountConfig != None:
      filterNames = []
      filterQueries = dict()
      for key in self.accountConfig.keys():
        filterMatch = regexMatch("^filter\\.(\\w+)$", key, re.IGNORECASE)
        if filterMatch != None:
          value = self.accountConfig[key]
          filterName = filterMatch.group(1)
          filterStr = value
          filterQueries[filterName] = filterStr
        elif key == "filterButtons":
          value = self.accountConfig[key]
          filterNames = list(map(str.strip, value.split(',')))

      for filterName in filterNames:
        if filterName in filterQueries:
          query = filterQueries[filterName]
          filterButtons.append(FilterButton(filterName, query, False, False))
    self.setFilterButtons(filterButtons)

    preferHtml = "false"
    if self.accountConfig != None and "prefer_html" in self.accountConfig.keys():
      preferHtml = self.accountConfig["prefer_html"]
    self.setHtmlMode(preferHtml != "false")
  def reset(self):
    self.setAccountName(None)
    self.setAccountConfig(None)
    self.setFolderName(None)
    self.setHeader(None)
    self.currentBodyText = None

  def setFilterButtons(self, filterButtons):
    self.filterButtons = []
    self.filterButtons.append(FilterButton(
      'unread', 'read=False', False, False))
    self.filterButtons += filterButtons
    self.filterButtonModel.setItems(self.filterButtons)

  def filterHeader(self, header):
    for f in self.headerFilters:
      if not f.filterHeader(header):
        return False
    return True

  @pyqtSlot(str, str, bool)
  def replaceHeaderFilterStr(self, name, headerFilterStr, isNegated):
    headerFilterStr = headerFilterStr.strip()
    attMatch = regexMatch("^(read)=(true|false)$", headerFilterStr, re.IGNORECASE)
    headers = self.currentHeaders

    if headerFilterStr == "" or len(headers) == 0:
      self.removeHeaderFilter(name)
      self.refreshHeaderFilters()
    elif attMatch:
      negatedFmt = "[NEGATED] " if isNegated else ""
      print("att filter: " + headerFilterStr)
      att = attMatch.group(1)
      val = attMatch.group(2)
      if val.lower() == "true":
        val = True
      elif val.lower() == "false":
        val = False

      if isNegated:
        val = not val
      headerFilter = HeaderFilterAtt(name, att, val)
      self.replaceHeaderFilter(headerFilter)
      self.refreshHeaderFilters()
    else:
      if isNegated:
        headerFilterStr = "!(" + headerFilterStr + ")"
      print("search filter: " + headerFilterStr)
      minUid = None
      maxUid = None
      for header in headers:
        if minUid == None or header.uid_ < minUid:
          minUid = header.uid_
        if maxUid == None or header.uid_ > maxUid:
          maxUid = header.uid_
      cmd = [EMAIL_SEARCH_BIN, "--search", "--folder="+self.folderName]
      if minUid != None:
        cmd += ["--minuid=" + str(minUid)]
      if maxUid != None:
        cmd += ["--maxuid=" + str(maxUid)]
      cmd += [self.accountName, headerFilterStr]
      self.notifierModel.notify("searching: " + str(cmd), False)
      self.startEmailCommandThread(cmd, None, self.onEmailSearchFinished, {"headerFilterName": name})
  def onEmailSearchFinished(self, isSuccess, output, extraArgs):
    self.notifierModel.hide()
    if not isSuccess:
      self.notifierModel.notify("\nSEARCH FAILED\n\n" + output, False)
      return
    try:
      uids = list(map(int, output.splitlines()))
      name = extraArgs["headerFilterName"]
      headerFilter = HeaderFilterWhitelist(name, uids)
      if headerFilter == None:
        self.removeHeaderFilter(name)
      else:
        self.replaceHeaderFilter(headerFilter)
    except Exception as e:
      print("Error parsing filter string: " + str(e))
      self.removeHeaderFilter(name)
    self.refreshHeaderFilters()
  @pyqtSlot(str)
  def removeHeaderFilter(self, name):
    self.headerFilters = list(filter(lambda f: f.name != name, self.headerFilters))
  @pyqtSlot()
  def refreshHeaderFilters(self):
    self.setHeaders(self.currentHeaders)

  def replaceHeaderFilter(self, headerFilter):
    name = headerFilter.name
    self.headerFilters = list(filter(lambda f: f.name != name, self.headerFilters))
    self.headerFilters.append(headerFilter)

  @pyqtSlot()
  def resetFilterButtons(self):
    for filterButton in self.filterButtonModel.getItems():
      filterButton.setChecked(False, False)

  def setHeaders(self, headers):
    self.currentHeaders = headers
    filteredHeaders = list(filter(self.filterHeader, headers))
    if len(filteredHeaders) == 0:
      self.headerModel.clear()
    else:
      self.headerModel.setItems(filteredHeaders)
    self.updateCounterBox()
  def prependHeaders(self, headers):
    newFilteredHeaders = list(filter(self.filterHeader, headers))
    self.currentHeaders += headers
    if len(newFilteredHeaders) > 0:
      self.headerModel.prependItems(newFilteredHeaders)
    self.updateCounterBox()
  def appendHeaders(self, headers):
    newFilteredHeaders = list(filter(self.filterHeader, headers))
    self.currentHeaders += headers
    if len(newFilteredHeaders) > 0:
      self.headerModel.appendItems(newFilteredHeaders)
    self.updateCounterBox()

  @pyqtSlot(str)
  def onSearchTextChanged(self, searchText):
    self.replaceHeaderFilterStr("quick-filter", searchText, False)

  @pyqtSlot(QObject, QObject)
  def updateAccount(self, messageBox, account):
    if account == None:
      accMsg = "ALL ACCOUNTS WITHOUT SKIP"
    else:
      accMsg = account.Name
    self.onAppendMessage(messageBox, "STARTING UPDATE FOR " + accMsg + "\n")

    if account != None:
      account.setLoading(True)

    cmd = [EMAIL_BIN, "--update"]
    if account != None:
      cmd.append(account.Name)

    self.startEmailCommandThread(cmd, messageBox,
      self.onUpdateAccountFinished, {})
  def onUpdateAccountFinished(self, isSuccess, output, extraArgs):
    self.setupAccounts()
    if self.accountName != None:
      self.ensureHeadersUpToDate()

  @pyqtSlot()
  def markAllRead(self):
    if self.accountName == None:
      return

    headerStates = []
    uids = []
    for header in self.headerModel.getItems():
      if not header.read_:
        header.setLoading(True)
        headerStates.append({'header': header, 'uid': header.uid_})
        uids.append(str(header.uid_))

    if len(uids) == 0:
      return

    cmd = [EMAIL_BIN, "--mark-read",
      "--folder=" + self.folderName, self.accountName] + uids

    self.startEmailCommandThread(cmd, None,
      self.onMarkAllReadFinished, {
        'accountName': self.accountName,
        'folderName': self.folderName,
        'headerStates': headerStates})
  def onMarkAllReadFinished(self, isSuccess, output, extraArgs):
    accountName = extraArgs['accountName']
    folderName = extraArgs['folderName']
    headerStates = extraArgs['headerStates']

    if accountName == self.accountName and folderName == self.folderName:
      for headerState in headerStates:
        header = headerState['header']
        if headerState['uid'] == header.uid_:
          header.setLoading(False)
          if isSuccess:
            header.setRead(True)

    self.setupAccounts()

  @pyqtSlot(QObject)
  def toggleRead(self, header):
    header.setLoading(True)

    if header.read_:
      arg = "--mark-unread"
    else:
      arg = "--mark-read"
    cmd = [EMAIL_BIN, arg,
      "--folder=" + self.folderName, self.accountName, str(header.uid_)]

    self.startEmailCommandThread(cmd, None,
      self.onToggleReadFinished, {'header': header})
  def onToggleReadFinished(self, isSuccess, output, extraArgs):
    header = extraArgs['header']
    header.isLoading_ = False
    header.setLoading(False)
    if isSuccess:
      header.setRead(not header.read_)
    self.setupAccounts()

  @pyqtSlot(bool)
  def setHtmlMode(self, htmlMode):
    self.htmlMode = htmlMode
    self.htmlModeChanged.emit()

  @pyqtSlot(QObject, QObject)
  def fetchCurrentBodyText(self, bodyBox, headerBox):
    self.fetchCurrentBodyTextWithTransform(bodyBox, headerBox, None, False)

  def fetchCurrentBodyTextWithTransform(self, bodyBox, headerBox,
      transform, forcePlain=False):
    self.currentBodyText = None
    bodyBox.setBody("...loading body")
    if self.header == None:
      self.notifierModel.notify("CURRENT MESSAGE NOT SET")
      return
    if headerBox != None:
      headerBox.setHeader(""
        + "From: " + self.header.From + "\n"
        + "Subject: " + self.header.Subject + "\n"
        + "To: " + self.header.To + "\n"
        + "CC: " + self.header.CC + "\n"
        + "BCC: " + self.header.BCC + "\n"
        + "Date: " + self.header.Date
        + "    (uid: " + str(self.header.Uid) + ")\n"
      );

    if self.htmlMode and not forcePlain:
      arg = "--body-html"
    else:
      arg = "--body-plain"

    cmd = [EMAIL_BIN, arg,
      "--folder=" + self.folderName, self.accountName, str(self.header.Uid)]

    self.startEmailCommandThread(cmd, None,
      self.onFetchCurrentBodyTextFinished, {'bodyBox': bodyBox, 'transform': transform})
  def onFetchCurrentBodyTextFinished(self, isSuccess, output, extraArgs):
    bodyBox = extraArgs['bodyBox']
    transform = extraArgs['transform']
    if transform:
      body = transform(output)
    else:
      body = output

    body = self.removeInlineCidImages(body)

    if isSuccess:
      self.currentBodyText = body
      bodyBox.setBody(body)
    else:
      self.currentBodyText = None
      bodyBox.setBody("ERROR FETCHING BODY\n")

  def removeInlineCidImages(self, text):
    return regexSub('src="cid:[^"]*"', '', text)

  @pyqtSlot(QObject)
  def copyBodyToClipboard(self, bodyView):
    curBody = self.currentBodyText
    curSel = bodyView.getSelectedText()
    text = None
    if curSel != None and len(curSel) > 0:
      text = curSel
    elif curBody != None and len(curBody) > 0:
      text = curBody

    if text != None:
      QApplication.clipboard().setText(text)
      self.notifierModel.notify("Copied text to clipboard: " + text)

  @pyqtSlot()
  def saveCurrentAttachments(self):
    if self.header == None:
      self.notifierModel.notify("MISSING CURRENT MESSAGE")
      return

    destDir = os.getenv("HOME")
    cmd = [EMAIL_BIN, "--attachments",
      "--folder=" + self.folderName, self.accountName, destDir, str(self.header.Uid)]

    self.startEmailCommandThread(cmd, None,
      self.onSaveCurrentAttachmentsFinished, {})
  def onSaveCurrentAttachmentsFinished(self, isSuccess, output, extraArgs):
    if output.strip() == "":
      output = "{no attachments}"
    if isSuccess:
      self.notifierModel.notify("success:\n" + output)
    else:
      self.notifierModel.notify("ERROR: saving attachments failed\n")

  def startEmailCommandThread(self, command, messageBox, finishedAction, extraArgs):
    print("starting command: " + str(command))
    thread = EmailCommandThread(
      command=command,
      messageBox=messageBox,
      finishedAction=finishedAction,
      extraArgs=extraArgs)
    thread.finished.connect(lambda: self.onThreadFinished(thread))
    thread.commandFinished.connect(self.onCommandFinished)
    thread.setMessage.connect(self.onSetMessage)
    thread.appendMessage.connect(self.onAppendMessage)
    self.threads.append(thread)
    thread.start()
  def onThreadFinished(self, thread):
    self.threads.remove(thread)
  def onCommandFinished(self, isSuccess, output, finishedAction, extraArgs):
    if finishedAction != None:
      finishedAction(isSuccess, output, extraArgs)
  def onSetMessage(self, messageBox, message):
    if messageBox != None:
      messageBox.setText(message)
  def onAppendMessage(self, messageBox, message):
    if messageBox != None:
      oldText = messageBox.getText()
      lines = oldText.splitlines()
      maxLines = 500
      if len(lines) > maxLines:
        lines = lines[0-maxLines:]
      oldText = "\n".join(lines) + "\n"
      messageBox.setText(oldText + message)
      messageBox.scrollToBottom()

  @pyqtSlot()
  def ensureHeadersUpToDate(self):
    minUid = min(map(lambda header: header.Uid, self.currentHeaders))
    (total, headers) = self.emailManager.fetchHeaders(
      self.accountName, self.folderName,
      limit=None, exclude=self.currentHeaders, minUid=minUid)
    self.totalSize = total
    self.prependHeaders(headers)

  @pyqtSlot(int)
  def moreHeaders(self, percentage):
    if self.accountName == None:
      return

    if percentage != None:
      limit = int(self.totalSize * percentage / 100)
    else:
      limit = 0
    if limit < PAGE_MORE_SIZE:
      limit = PAGE_MORE_SIZE
    (total, headers) = self.emailManager.fetchHeaders(
      self.accountName, self.folderName,
      limit=limit, exclude=self.currentHeaders, minUid=None)
    self.totalSize = total
    self.appendHeaders(headers)

  @pyqtSlot()
  def updateCounterBox(self):
    if self.counterBox == None:
      return
    totalLen = self.totalSize
    curLen = len(self.currentHeaders)
    showingLen = len(self.headerModel.getItems())
    msg = ""
    if showingLen != curLen:
      msg += "(" + str(showingLen) + " showing)  "
    msg += str(curLen) + " / " + str(totalLen)
    self.counterBox.setCounterText(msg)

  def AccountName(self):
    return self.accountName

  def HtmlMode(self):
    return self.htmlMode

  accountNameChanged = pyqtSignal()
  AccountName = pyqtProperty(STR_TYPE, AccountName, notify=accountNameChanged)
  htmlModeChanged = pyqtSignal()
  HtmlMode = pyqtProperty(bool, HtmlMode, notify=htmlModeChanged)

class HeaderFilter():
  def __init__(self, name):
    self.name = name
  def filterHeader(self, header):
    return True

class HeaderFilterWhitelist(HeaderFilter):
  def __init__(self, name, uids):
    HeaderFilter.__init__(self, name)
    self.name = name
    self.okUids = set(uids)
  def filterHeader(self, header):
    return header.uid_ in self.okUids

class HeaderFilterAtt(HeaderFilter):
  def __init__(self, name, att, value):
    HeaderFilter.__init__(self, name)
    self.att = att
    self.value = value
  def filterHeader(self, header):
    if self.att == "read":
      return header.read_ == self.value
    return True


class EmailCommandThread(QThread):
  commandFinished = pyqtSignal(bool, str, object, dict)
  setMessage = pyqtSignal(QObject, str)
  appendMessage = pyqtSignal(QObject, str)
  def __init__(self, command, messageBox=None, finishedAction=None, extraArgs=None):
    QThread.__init__(self)
    self.command = command
    self.messageBox = messageBox
    self.finishedAction = finishedAction
    self.extraArgs = extraArgs
  def run(self):
    proc = subprocess.Popen(self.command, stdout=subprocess.PIPE)
    output = ""
    while True:
      line = proc.stdout.readline()
      if not line:
         break
      line = toStr(line)
      self.appendMessage.emit(self.messageBox, line)
      output += line
    proc.wait()

    if proc.returncode == 0:
      success = True
      status = "SUCCESS\n"
    else:
      success = False
      status = "FAILURE\n"

    self.appendMessage.emit(self.messageBox, status)

    self.commandFinished.emit(success, output, self.finishedAction, self.extraArgs)

class BaseListModel(QAbstractListModel):
  def __init__(self):
    QAbstractListModel.__init__(self)
    self.items = []
  def getItems(self):
    return self.items
  def setItems(self, items):
    self.clear()
    self.prependItems(items)
  def prependItems(self, items):
    if len(items) > 0:
      firstNewRow = 0
      lastNewRow = len(items) - 1
      self.beginInsertRows(QModelIndex(), firstNewRow, lastNewRow)
      self.items = items + self.items
      self.endInsertRows()
      self.changed.emit()
  def appendItems(self, items):
    if len(items) > 0:
      firstNewRow = len(self.items)
      lastNewRow = len(self.items) + len(items) - 1
      self.beginInsertRows(QModelIndex(), firstNewRow, lastNewRow)
      self.items.extend(items)
      self.endInsertRows()
      self.changed.emit()
  @pyqtSlot(result=int)
  def rowCount(self, parent=QModelIndex()):
    return len(self.items)
  def count(self):
    return len(self.items)
  @pyqtSlot(int, result=QObject)
  def get(self, index):
    return self.items[index]
  def data(self, index, role):
    if role == Qt.DisplayRole:
      return self.items[index.row()]
  def clear(self):
    self.removeRows(0, len(self.items))
    self.items = []
  def removeRows(self, firstRow, rowCount, parent = QModelIndex()):
    self.beginRemoveRows(parent, firstRow, firstRow+rowCount-1)
    while rowCount > 0:
      del self.items[firstRow]
      rowCount -= 1
    self.endRemoveRows()
    self.changed.emit()
  changed = pyqtSignal()
  count = pyqtProperty(int, count, notify=changed)

class AccountModel(BaseListModel):
  COLUMNS = (b'account',)
  def __init__(self):
    BaseListModel.__init__(self)
  def roleNames(self):
    return dict(enumerate(AccountModel.COLUMNS))

class FolderModel(BaseListModel):
  COLUMNS = (b'folder',)
  def __init__(self):
    BaseListModel.__init__(self)
  def roleNames(self):
    return dict(enumerate(FolderModel.COLUMNS))

class HeaderModel(BaseListModel):
  COLUMNS = (b'header',)
  def __init__(self):
    BaseListModel.__init__(self)
  def roleNames(self):
    return dict(enumerate(HeaderModel.COLUMNS))

class ConfigModel(BaseListModel):
  COLUMNS = (b'config',)
  def __init__(self):
    BaseListModel.__init__(self)
  def roleNames(self):
    return dict(enumerate(ConfigModel.COLUMNS))

class FilterButtonModel(BaseListModel):
  COLUMNS = (b'filterButton',)
  def __init__(self):
    BaseListModel.__init__(self)
  def roleNames(self):
    return dict(enumerate(FilterButtonModel.COLUMNS))

class AddressBookModel(BaseListModel):
  COLUMNS = (b'address',)
  def __init__(self):
    BaseListModel.__init__(self)
  def roleNames(self):
    return dict(enumerate(AddressBookModel.COLUMNS))

class FileListModel(BaseListModel):
  COLUMNS = (b'path',)
  def __init__(self):
    BaseListModel.__init__(self)
  def roleNames(self):
    return dict(enumerate(FileListModel.COLUMNS))

class FileInfoModel(BaseListModel):
  COLUMNS = (b'fileInfo',)
  def __init__(self):
    BaseListModel.__init__(self)
  def roleNames(self):
    return dict(enumerate(FileInfoModel.COLUMNS))


class Account(QObject):
  def __init__(self, name_, lastUpdated_, lastUpdatedRel_, updateInterval_, refreshInterval_, unread_, total_, error_, isLoading_):
    QObject.__init__(self)
    self.name_ = name_
    self.lastUpdated_ = lastUpdated_
    self.lastUpdatedRel_ = lastUpdatedRel_
    self.updateInterval_ = updateInterval_
    self.refreshInterval_ = refreshInterval_
    self.unread_ = unread_
    self.total_ = total_
    self.error_ = error_
    self.isLoading_ = isLoading_
    self.selected_ = False
  def Name(self):
    return self.name_
  def LastUpdated(self):
    return self.lastUpdated_
  def LastUpdatedRel(self):
    return self.lastUpdatedRel_
  def UpdateInterval(self):
    return self.updateInterval_
  def RefreshInterval(self):
    return self.refreshInterval_
  def Unread(self):
    return self.unread_
  def Total(self):
    return self.total_
  def Error(self):
    return self.error_
  def IsLoading(self):
    return self.isLoading_
  def Selected(self):
    return self.selected_
  def refresh(self, lastUpdated_, lastUpdatedRel_, updateInterval_, refreshInterval_, unread_, total_, error_):
    self.lastUpdated_ = lastUpdated_
    self.lastUpdatedRel_ = lastUpdatedRel_
    self.updateInterval_ = updateInterval_
    self.refreshInterval_ = refreshInterval_
    self.unread_ = unread_
    self.total_ = total_
    self.error_ = error_
    self.changed.emit()
  def setLoading(self, isLoading_):
    self.isLoading_ = isLoading_
    self.changed.emit()
  def setSelected(self, selected_):
    self.selected_ = selected_
    self.changed.emit()
  changed = pyqtSignal()
  Name = pyqtProperty(STR_TYPE, Name, notify=changed)
  LastUpdated = pyqtProperty(int, LastUpdated, notify=changed)
  LastUpdatedRel = pyqtProperty(STR_TYPE, LastUpdatedRel, notify=changed)
  UpdateInterval = pyqtProperty(int, UpdateInterval, notify=changed)
  RefreshInterval = pyqtProperty(int, RefreshInterval, notify=changed)
  Unread = pyqtProperty(int, Unread, notify=changed)
  Total = pyqtProperty(int, Total, notify=changed)
  Error = pyqtProperty(STR_TYPE, Error, notify=changed)
  IsLoading = pyqtProperty(bool, IsLoading, notify=changed)
  Selected = pyqtProperty(bool, Selected, notify=changed)

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
  changed = pyqtSignal()
  Name = pyqtProperty(STR_TYPE, Name, notify=changed)
  Unread = pyqtProperty(int, Unread, notify=changed)
  Total = pyqtProperty(int, Total, notify=changed)

class Header(QObject):
  def __init__(self, uid_, date_, from_, to_, cc_, bcc_, subject_, isSent_, read_, isLoading_):
    QObject.__init__(self)
    self.uid_ = uid_
    self.date_ = date_
    self.from_ = from_
    self.to_ = to_
    self.cc_ = cc_
    self.bcc_ = bcc_
    self.subject_ = subject_
    self.isSent_ = isSent_
    self.read_ = read_
    self.isLoading_ = isLoading_
    self.selected_ = False
  def Uid(self):
    return self.uid_
  def Date(self):
    return self.date_
  def From(self):
    return self.from_
  def To(self):
    return self.to_
  def CC(self):
    return self.cc_
  def BCC(self):
    return self.bcc_
  def Subject(self):
    return self.subject_
  def IsSent(self):
    return self.isSent_
  def Read(self):
    return self.read_
  def IsLoading(self):
    return self.isLoading_
  def Selected(self):
    return self.selected_
  def setLoading(self, isLoading_):
    self.isLoading_ = isLoading_
    self.changed.emit()
  def setRead(self, read_):
    self.read_ = read_
    self.changed.emit()
  def setSelected(self, selected_):
    self.selected_ = selected_
    self.changed.emit()
  changed = pyqtSignal()
  Uid = pyqtProperty(int, Uid, notify=changed)
  Date = pyqtProperty(STR_TYPE, Date, notify=changed)
  From = pyqtProperty(STR_TYPE, From, notify=changed)
  To = pyqtProperty(STR_TYPE, To, notify=changed)
  CC = pyqtProperty(STR_TYPE, CC, notify=changed)
  BCC = pyqtProperty(STR_TYPE, BCC, notify=changed)
  Subject = pyqtProperty(STR_TYPE, Subject, notify=changed)
  IsSent = pyqtProperty(bool, IsSent, notify=changed)
  Read = pyqtProperty(bool, Read, notify=changed)
  IsLoading = pyqtProperty(bool, IsLoading, notify=changed)
  Selected = pyqtProperty(bool, Selected, notify=changed)

class Field(QObject):
  def __init__(self, fieldName_, isPassword_, value_, description_):
    QObject.__init__(self)
    self.fieldName_ = fieldName_
    self.isPassword_ = isPassword_
    self.value_ = value_
    self.description_ = description_
  def FieldName(self):
    return self.fieldName_
  def IsPassword(self):
    return self.isPassword_
  def Value(self):
    return self.value_
  def Description(self):
    return self.description_
  changed = pyqtSignal()
  FieldName = pyqtProperty(STR_TYPE, FieldName, notify=changed)
  IsPassword = pyqtProperty(bool, IsPassword, notify=changed)
  Value = pyqtProperty(STR_TYPE, Value, notify=changed)
  Description = pyqtProperty(STR_TYPE, Description, notify=changed)

class FilterButton(QObject):
  def __init__(self, name_, filterString_, isChecked_, isNegated_):
    QObject.__init__(self)
    self.name_ = name_
    self.filterString_ = filterString_
    self.isChecked_ = isChecked_
    self.isNegated_ = isNegated_
  def Name(self):
    return self.name_
  def FilterString(self):
    return self.filterString_
  def IsChecked(self):
    return self.isChecked_
  def IsNegated(self):
    return self.isNegated_
  @pyqtSlot(bool, bool)
  def setChecked(self, isChecked_, isNegated_):
    # notify on negated first
    self.isNegated_ = isNegated_
    self.negatedChanged.emit()

    self.isChecked_ = isChecked_
    self.checkedChanged.emit()
  cfgChanged = pyqtSignal()
  checkedChanged = pyqtSignal()
  negatedChanged = pyqtSignal()
  Name = pyqtProperty(STR_TYPE, Name, notify=cfgChanged)
  FilterString = pyqtProperty(STR_TYPE, FilterString, notify=cfgChanged)
  IsChecked = pyqtProperty(bool, IsChecked, notify=checkedChanged)
  IsNegated = pyqtProperty(bool, IsNegated, notify=negatedChanged)

class NotifierModel(QObject):
  def __init__(self):
    QObject.__init__(self)
    self.text_ = ""
    self.showing_ = False
    self.hideDelay_ = True
  def Text(self):
    return self.text_
  def Showing(self):
    return self.showing_
  def HideDelay(self):
    return self.hideDelay_
  def notify(self, text_, hideDelay_=True):
    self.showing_ = False
    self.changed.emit()

    self.text_ = text_
    self.showing_ = True
    self.hideDelay_ = hideDelay_

    self.changed.emit()
  def hide(self):
    self.setShowing(False)
  @pyqtSlot(bool)
  def setShowing(self, showing_):
    self.showing_ = showing_
    self.changed.emit()
  changed = pyqtSignal()
  Text = pyqtProperty(STR_TYPE, Text, notify=changed)
  Showing = pyqtProperty(bool, Showing, notify=changed)
  HideDelay = pyqtProperty(bool, HideDelay, notify=changed)

class Suggestion(QObject):
  def __init__(self, suggestionText_, parent):
    QObject.__init__(self, parent)
    self.suggestionText_ = suggestionText_
  def name(self):
    return self.suggestionText_
  changed = pyqtSignal()
  name = pyqtProperty(STR_TYPE, name, notify=changed)

class FileInfo(QObject):
  def __init__(self, filePath_, sizeFmt_, mtimeFmt_, errorMsg_):
    QObject.__init__(self)
    self.filePath_ = filePath_
    self.sizeFmt_ = sizeFmt_
    self.mtimeFmt_ = mtimeFmt_
    self.errorMsg_ = errorMsg_
  def FilePath(self):
    return self.filePath_
  def SizeFmt(self):
    return self.sizeFmt_
  def MtimeFmt(self):
    return self.mtimeFmt_
  def ErrorMsg(self):
    return self.errorMsg_
  changed = pyqtSignal()
  FilePath = pyqtProperty(STR_TYPE, FilePath, notify=changed)
  SizeFmt = pyqtProperty(STR_TYPE, SizeFmt, notify=changed)
  MtimeFmt = pyqtProperty(STR_TYPE, MtimeFmt, notify=changed)
  ErrorMsg = pyqtProperty(STR_TYPE, ErrorMsg, notify=changed)

class MainWindow(QQuickView):
  def __init__(self, qmlFile, controller,
    accountModel, folderModel, headerModel, configModel, filterButtonModel, notifierModel,
    addressBookModel, fileListModel, fileInfoModel):
    super(MainWindow, self).__init__(None)
    context = self.rootContext()
    context.setContextProperty('accountModel', accountModel)
    context.setContextProperty('folderModel', folderModel)
    context.setContextProperty('headerModel', headerModel)
    context.setContextProperty('configModel', configModel)
    context.setContextProperty('filterButtonModel', filterButtonModel)
    context.setContextProperty('notifierModel', notifierModel)
    context.setContextProperty('addressBookModel', addressBookModel)
    context.setContextProperty('fileListModel', fileListModel)
    context.setContextProperty('fileInfoModel', fileInfoModel)
    context.setContextProperty('controller', controller)

    self.setResizeMode(QQuickView.SizeRootObjectToView)
    self.setSource(QUrl(qmlFile))

    # copy QObject properties into context *after* QML initialization
    context.setContextProperty('main', self.rootObject())
    context.setContextProperty('scaling', self.rootObject().property('scaling'))

class SendWindow(QQuickView):
  def __init__(self, qmlFile, controller, mainWindow,
    accountModel, folderModel, headerModel, configModel, filterButtonModel, notifierModel,
    addressBookModel, fileListModel, fileInfoModel):
    super(SendWindow, self).__init__(None)

    context = self.rootContext()
    context.setContextProperty('accountModel', accountModel)
    context.setContextProperty('folderModel', folderModel)
    context.setContextProperty('headerModel', headerModel)
    context.setContextProperty('configModel', configModel)
    context.setContextProperty('filterButtonModel', filterButtonModel)
    context.setContextProperty('notifierModel', notifierModel)
    context.setContextProperty('addressBookModel', addressBookModel)
    context.setContextProperty('fileListModel', fileListModel)
    context.setContextProperty('fileInfoModel', fileInfoModel)
    context.setContextProperty('controller', controller)

    # copy MainWindow QObject properties into context *before* SendWindow QML initialization
    context.setContextProperty('main', mainWindow.rootObject())
    context.setContextProperty('scaling', mainWindow.rootObject().property('scaling'))

    self.setResizeMode(QQuickView.SizeRootObjectToView)
    self.setSource(QUrl(qmlFile))


def listModelToArray(listModel, obj=None):
  arr = []
  for row in range(0, listModel.rowCount()):
    index = listModel.index(row, 0)
    val = listModel.data(index, 0)
    arr.append(val)
  return arr

def regexMatch(pattern, string, flags=0):
  if PYTHON3:
    string = toStr(string)
  return re.match(pattern, string, flags)

def regexSub(pattern, repl, string, count=0, flags=0):
  if PYTHON3:
    string = toStr(string)
  return re.sub(pattern, repl, string, count, flags)

def toStr(string):
  if type(string) == str:
    return string
  else:
    try:
      return string.decode("utf-8")
    except:
      return str(string)

if __name__ == "__main__":
  sys.exit(main())
