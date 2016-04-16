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

EMAIL_BIN = "/opt/qtemail/bin/email.pl"
EMAIL_SEARCH_BIN = "/opt/qtemail/bin/email-search.pl"
QML_DIR = "/opt/qtemail/qml"

PLATFORM_OTHER = 0
PLATFORM_HARMATTAN = 1
PLATFORM_FREMANTLE = 2
platform = [None]

signal.signal(signal.SIGINT, signal.SIG_DFL)

PAGE_INITIAL_SIZE = 200
PAGE_MORE_SIZE = 200

EMAIL_DIR = os.getenv("HOME") + "/.cache/email"
CONFIG_DIR = os.getenv("HOME") + "/.config/qtemail"

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
""" % {"exec": sys.argv[0], "okPages": okPages}

def warn(msg):
  print >> sys.stderr, msg
def die(msg):
  warn(msg)
  sys.exit(1)

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
      die(usage)
  if len(args) > 0:
    die(usage)

  issue = open('/etc/issue').read().strip().lower()
  platform[0] = None
  if "harmattan" in issue:
    platform[0] = PLATFORM_HARMATTAN
  elif "maemo 5" in issue:
    platform[0] = PLATFORM_FREMANTLE
  else:
    platform[0] = PLATFORM_OTHER

  if platform[0] == PLATFORM_HARMATTAN:
    qmlFile = QML_DIR + "/harmattan.qml"
  elif platform[0] == PLATFORM_FREMANTLE:
    qmlFile = QML_DIR + "/desktop-small.qml"
  else:
    qmlFile = QML_DIR + "/desktop.qml"

  emailManager = EmailManager()
  accountModel = AccountModel()
  folderModel = FolderModel()
  headerModel = HeaderModel()
  configModel = ConfigModel()
  notifierModel = NotifierModel()
  filterButtonModel = FilterButtonModel()
  addressBookModel = AddressBookModel()
  fileListModel = FileListModel()
  controller = Controller(emailManager,
    accountModel, folderModel, headerModel, configModel, filterButtonModel, notifierModel,
    addressBookModel, fileListModel)

  controller.setupAccounts()

  if 'page' in opts:
    controller.setInitialPageName(opts['page'])
  if 'account' in opts:
    controller.accountSelected(opts['account'])
  if 'folder' in opts:
    controller.setFolderName(opts['folder'])
  if 'uid' in opts:
    hdr = emailManager.getHeader(opts['account'], opts['folder'], opts['uid'])
    controller.setHeader(hdr)

  app = QApplication([])
  mainWindow = MainWindow(qmlFile, controller,
    accountModel, folderModel, headerModel, configModel, filterButtonModel, notifierModel,
    addressBookModel, fileListModel)

  if platform[0] == PLATFORM_OTHER:
    sendWindow = SendWindow(QML_DIR + "/SendView.qml", controller, mainWindow.rootObject(),
      accountModel, folderModel, headerModel, configModel, filterButtonModel, notifierModel,
      addressBookModel, fileListModel)
    sendView = sendWindow.rootObject()
    mainWindow.rootContext().setContextProperty('sendView', sendView)
    sendView.setNotifierEnabled(True)

    controller.setSendWindow(sendWindow)

  if platform[0] == PLATFORM_HARMATTAN:
    mainWindow.window().showFullScreen()
  else:
    mainWindow.window().show()

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
      configOut = configOut.replace('%', '%boing%')
      configOut = configOut.replace('\\\n', '%linebreak%')

      for line in configOut.splitlines():
        m = re.match("(\w+)=(.*)", line)
        if m:
          fieldName = m.group(1)
          value = m.group(2)
          value = value.replace('%linebreak%', '\n')
          value = value.replace('%boing%', '%')
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
      m = re.match("(\w+)\s*=\s*(.+)", line)
      if m:
        key = m.group(1)
        desc = m.group(2)
        schema.append((key, desc))
    return schema

  def getConfigFields(self, schema, configValues):
    fieldNames = map(lambda (k,v): k, schema)
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
      m = re.match("(\w+):(\d+):([a-z0-9_\- ]+):(\d+)s:(\d+)s:(\d+)/(\d+):(.*)", line)
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
    folderOut = self.readProc([EMAIL_BIN, "--folders", accountName])
    folders = []
    for line in folderOut.splitlines():
      m = re.match("([a-zA-Z_]+):(\d+)/(\d+)", line)
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
  def fetchHeaders(self, accName, folderName, limit=None, exclude=[], minUid=None):
    uids = self.getUids(accName, folderName, "all")
    uids.sort()
    uids.reverse()
    total = len(uids)
    if minUid != None:
      uids = filter(lambda uid: uid >= minUid, uids)
    if len(exclude) > 0:
      exUids = set(map(lambda header: header.uid_, exclude))
      uids = filter(lambda uid: uid not in exUids, uids)
    if limit != None:
      uids = uids[0:limit]
    unread = set(self.getUids(accName, folderName, "unread"))
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
      "--folder=" + folderName, accountName] + map(str,uids)
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
          body = re.sub(r'[^\x00-\x7F]', ' ', body).encode('utf-8')
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
      if re.match(commentRegex, line):
        continue
      accNameMatcher = re.match(accNameRegex, line)
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
    addressBookModel, fileListModel):
    QObject.__init__(self)
    self.emailManager = emailManager
    self.accountModel = accountModel
    self.folderModel = folderModel
    self.headerModel = headerModel
    self.configModel = configModel
    self.filterButtonModel = filterButtonModel
    self.notifierModel = notifierModel
    self.addressBookModel = addressBookModel
    self.fileListModel = fileListModel
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
    self.fileSystemController = FileSystemController()
    self.setFilterButtons([])
    self.addressBook = None
    self.sendWindow = None
    self.counterBox = None

  @Slot(QObject)
  def setCounterBox(self, counterBox):
    self.counterBox = counterBox

  def setSendWindow(self, sendWindow):
    self.sendWindow = sendWindow

  @Slot()
  def showSendWindow(self):
    self.sendWindow.show()

  @Slot('QVariantList')
  def runCommand(self, cmdArr):
    subprocess.Popen(cmdArr)
  @Slot(str)
  def shellCommand(self, cmdStr):
    subprocess.Popen(['sh', '-c', cmdStr])

  @Slot(QObject, str, result=QObject)
  def findChild(self, obj, name):
    return obj.findChild(QObject, name)

  @Slot(str, QObject)
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

    self.fetchCurrentBodyText(sendForm, None,
      lambda body: self.wrapBody(body, date, firstFrom), True)

  def wrapBody(self, body, date, author):
    bodyPrefix = "\n\nOn " + date + ", " + author + " wrote:\n"
    lines = [""] + body.splitlines()
    indentedBody = "\n".join(map(lambda line: "> " + line, lines)) + "\n"
    return bodyPrefix + indentedBody

  @Slot(QObject)
  def sendEmail(self, sendForm):
    to = sendForm.getTo()
    cc = sendForm.getCC()
    bcc = sendForm.getBCC()
    subject = sendForm.getSubject()
    body = sendForm.getBody()
    attachments = sendForm.getAttachments()
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

  @Slot()
  def setupAccounts(self):
    self.accountModel.setItems(self.emailManager.getAccounts())
    self.ensureAccountModelSelected()
  @Slot()
  def setupFolders(self):
    self.folderModel.setItems(self.emailManager.getFolders(self.accountName))
  @Slot()
  def setupHeaders(self):
    self.headerFilters = []
    (total, headers) = self.emailManager.fetchHeaders(
      self.accountName, self.folderName,
      limit=PAGE_INITIAL_SIZE, exclude=[], minUid=None)
    self.totalSize = total
    self.setHeaders(headers)
  @Slot(str)
  def setConfigMode(self, mode):
    self.configMode = mode
  @Slot()
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

  @Slot(QObject, str)
  def updateConfigFieldValue(self, field, value):
    field.value_ = value
  @Slot(result=bool)
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

  @Slot(str)
  def accountSelected(self, accountName):
    self.setAccountName(accountName)
    self.setFolderName("inbox")
    self.setAccountConfig(self.emailManager.readConfig("account", accountName))
    self.setupFolders()
    self.ensureAccountModelSelected()
    self.ensureAddressBook()
  @Slot(QObject)
  def folderSelected(self, folder):
    self.setFolderName(folder.Name)
  @Slot(QObject)
  def headerSelected(self, header):
    self.setHeader(header)
  @Slot()
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
        items.append(Suggestion(emailAddress))
      self.addressBookModel.setItems(items)

  @Slot(str, result=str)
  def getAccountConfigValue(self, configKey):
    if self.accountConfig != None and configKey in self.accountConfig:
      return self.accountConfig[configKey]
    return ''

  @Slot(result=str)
  def getInitialPageName(self):
    return self.initialPageName
  def setInitialPageName(self, pageName):
    self.initialPageName = pageName

  def setAccountName(self, accName):
    self.accountName = accName
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
    if self.accountConfig == None or not 'filters' in self.accountConfig.keys():
      filterButtons = []
    else:
      filterButtons = self.parseFilterButtons(self.accountConfig['filters'])
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

  def parseFilterButtons(self, filterButtonStr):
    filterButtonRegex = "(\\w+)=%(.+?)%\\s*"
    usedNames = set()
    filterButtons = []
    for f in re.findall(filterButtonRegex, filterButtonStr, re.DOTALL):
      name = f[0]
      filterStr = f[1]
      if not name in usedNames:
        filterButtons.append(FilterButton(name, filterStr, False))
      usedNames.add(name)
    return filterButtons
  def setFilterButtons(self, filterButtons):
    self.filterButtons = []
    self.filterButtons.append(FilterButton(
      'unread', 'read=False', False))
    self.filterButtons += filterButtons
    self.filterButtonModel.setItems(self.filterButtons)

  def filterHeader(self, header):
    for f in self.headerFilters:
      if not f.filterHeader(header):
        return False
    return True

  @Slot(str, str)
  def replaceHeaderFilterStr(self, name, headerFilterStr):
    headerFilterStr = headerFilterStr.strip()
    print headerFilterStr
    attMatch = re.match("^(read)=(true|false)$", headerFilterStr, re.IGNORECASE)
    headers = self.currentHeaders

    if headerFilterStr == "" or len(headers) == 0:
      self.removeHeaderFilter(name)
      self.refreshHeaderFilters()
    elif attMatch:
      att = attMatch.group(1)
      val = attMatch.group(2)
      if val.lower() == "true":
        val = True
      if val.lower() == "false":
        val = False
      headerFilter = HeaderFilterAtt(name, att, val)
      self.replaceHeaderFilter(headerFilter)
      self.refreshHeaderFilters()
    else:
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
      uids = map(int, output.splitlines())
      name = extraArgs["headerFilterName"]
      headerFilter = HeaderFilterWhitelist(name, uids)
      if headerFilter == None:
        self.removeHeaderFilter(name)
      else:
        self.replaceHeaderFilter(headerFilter)
    except Exception, e:
      print "Error parsing filter string:", e
      self.removeHeaderFilter(name)
    self.refreshHeaderFilters()
  @Slot(str)
  def removeHeaderFilter(self, name):
    self.headerFilters = filter(lambda f: f.name != name, self.headerFilters)
  @Slot()
  def refreshHeaderFilters(self):
    self.setHeaders(self.currentHeaders)

  def replaceHeaderFilter(self, headerFilter):
    name = headerFilter.name
    self.headerFilters = filter(lambda f: f.name != name, self.headerFilters)
    self.headerFilters.append(headerFilter)

  @Slot()
  def resetFilterButtons(self):
    for filterButton in self.filterButtonModel.getItems():
      filterButton.setChecked(False)

  def setHeaders(self, headers):
    self.currentHeaders = headers
    filteredHeaders = filter(self.filterHeader, headers)
    if len(filteredHeaders) == 0:
      self.headerModel.clear()
    else:
      self.headerModel.setItems(filteredHeaders)
    self.updateCounterBox()
  def prependHeaders(self, headers):
    newFilteredHeaders = filter(self.filterHeader, headers)
    self.currentHeaders += headers
    if len(newFilteredHeaders) > 0:
      self.headerModel.prependItems(newFilteredHeaders)
    self.updateCounterBox()
  def appendHeaders(self, headers):
    newFilteredHeaders = filter(self.filterHeader, headers)
    self.currentHeaders += headers
    if len(newFilteredHeaders) > 0:
      self.headerModel.appendItems(newFilteredHeaders)
    self.updateCounterBox()

  @Slot(str)
  def onSearchTextChanged(self, searchText):
    self.replaceHeaderFilterStr("quick-filter", searchText)

  @Slot(QObject, QObject)
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

  @Slot()
  def markAllRead(self):
    headers = []
    uids = []
    for header in self.headerModel.getItems():
      if not header.read_:
        header.setLoading(True)
        headers.append(header)
        uids.append(str(header.uid_))

    cmd = [EMAIL_BIN, "--mark-read",
      "--folder=" + self.folderName, self.accountName] + uids

    self.startEmailCommandThread(cmd, None,
      self.onMarkAllReadFinished, {'headers': headers})
  def onMarkAllReadFinished(self, isSuccess, output, extraArgs):
    headers = extraArgs['headers']
    for header in headers:
      header.setLoading(False)
    if isSuccess:
      for header in self.headerModel.getItems():
        header.setRead(True)
    self.setupAccounts()

  @Slot(QObject)
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

  @Slot(result=bool)
  def getHtmlMode(self):
    return self.htmlMode
  @Slot(bool)
  def setHtmlMode(self, htmlMode):
    self.htmlMode = htmlMode

  @Slot(QObject, QObject, object)
  def fetchCurrentBodyText(self, bodyBox, headerBox, transform, forcePlain=False):
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

    if isSuccess:
      self.currentBodyText = body
      bodyBox.setBody(body)
    else:
      self.currentBodyText = None
      bodyBox.setBody("ERROR FETCHING BODY\n")

  @Slot(QObject)
  def copyBodyToClipboard(self, bodyView):
    curBody = self.currentBodyText
    curSel = bodyView.getSelectedText()
    text = None
    if curSel != None and len(curSel) > 0:
      text = curSel
    elif curBody != None and len(curBody) > 0:
      text = curBody

    if text != None:
      QClipboard().setText(text)
    self.notifierModel.notify("Copied text to clipboard: " + text)

  @Slot()
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

  @Slot()
  def ensureHeadersUpToDate(self):
    minUid = min(map(lambda header: header.Uid, self.currentHeaders))
    (total, headers) = self.emailManager.fetchHeaders(
      self.accountName, self.folderName,
      limit=None, exclude=self.currentHeaders, minUid=minUid)
    self.totalSize = total
    self.prependHeaders(headers)
  @Slot(int)
  def moreHeaders(self, percentage):
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

class FileSystemController(QObject):
  def __init__(self):
    QObject.__init__(self)
    self.dirModel = None

  def ensureDirModel(self):
    if self.dirModel == None:
      self.dirModel = QDirModel()
      self.dirModel.setSorting(QDir.DirsFirst)
      self.dirModel.setFilter(QDir.AllEntries | QDir.NoDot | QDir.NoDotDot)

  @Slot(result=str)
  def getHome(self):
    return os.getenv("HOME")

  @Slot(result=QObject)
  def getDirModel(self):
    self.ensureDirModel()
    return self.dirModel
  @Slot(str, result=QModelIndex)
  def getModelIndex(self, path):
    self.ensureDirModel()
    return self.dirModel.index(path)
  @Slot(QModelIndex, result=str)
  def getFilePath(self, index):
    self.ensureDirModel()
    return self.dirModel.filePath(index)
  @Slot(QModelIndex, result=bool)
  def isDir(self, index):
    self.ensureDirModel()
    p = self.getFilePath(index)
    if p:
      return self.dirModel.isDir(index)
    else:
      return False
  @Slot(str, result=QObject)
  def setDirModelPath(self, path):
    index = self.dirModel.index(path)
    self.dirModel.refresh(parent=index)

  @Slot(result=bool)
  def checkDirModelFucked(self):
    try:
      if self.dirModel:
        self.dirModel.isReadOnly()
    except:
      print "\n\n\n\n\n\nQDirModel is FUUUUUUCKED\n\n"
      self.dirModel = None
      self.ensureDirModel()
      return True
    return False


class EmailCommandThread(QThread):
  commandFinished = Signal(bool, str, object, list)
  setMessage = Signal(QObject, str)
  appendMessage = Signal(QObject, str)
  def __init__(self, command, messageBox=None, finishedAction=None, extraArgs=None):
    QThread.__init__(self)
    self.command = command
    self.messageBox = messageBox
    self.finishedAction = finishedAction
    self.extraArgs = extraArgs
  def run(self):
    proc = subprocess.Popen(self.command, stdout=subprocess.PIPE)
    output = ""
    for line in iter(proc.stdout.readline,''):
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
    if len(items) > 0:
      self.beginInsertRows(QModelIndex(), 0, 0)
      self.items = items
      self.endInsertRows()
    else:
      self.items = []
    self.changed.emit()
  def prependItems(self, items):
    self.beginInsertRows(QModelIndex(), 0, len(items) - 1)
    self.items = items + self.items
    self.endInsertRows()
    self.changed.emit()
  def appendItems(self, items):
    self.beginInsertRows(QModelIndex(), len(self.items), len(self.items))
    self.items.extend(items)
    self.endInsertRows()
    self.changed.emit()
  @Slot(result=int)
  def rowCount(self, parent=QModelIndex()):
    return len(self.items)
  def count(self):
    return len(self.items)
  @Slot(int, result=QObject)
  def get(self, index):
    return self.items[index]
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
    self.changed.emit()
  changed = Signal()
  count = Property(int, count, notify=changed)

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

class FilterButtonModel(BaseListModel):
  COLUMNS = ('filterButton',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(FilterButtonModel.COLUMNS)))

class AddressBookModel(BaseListModel):
  COLUMNS = ('address',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(AddressBookModel.COLUMNS)))

class FileListModel(BaseListModel):
  COLUMNS = ('path',)
  def __init__(self):
    BaseListModel.__init__(self)
    self.setRoleNames(dict(enumerate(FileListModel.COLUMNS)))

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
  def setLoading(self, isLoading_):
    self.isLoading_ = isLoading_
    self.changed.emit()
  def setSelected(self, selected_):
    self.selected_ = selected_
    self.changed.emit()
  changed = Signal()
  Name = Property(unicode, Name, notify=changed)
  LastUpdated = Property(int, LastUpdated, notify=changed)
  LastUpdatedRel = Property(unicode, LastUpdatedRel, notify=changed)
  UpdateInterval = Property(int, UpdateInterval, notify=changed)
  RefreshInterval = Property(int, RefreshInterval, notify=changed)
  Unread = Property(int, Unread, notify=changed)
  Total = Property(int, Total, notify=changed)
  Error = Property(unicode, Error, notify=changed)
  IsLoading = Property(bool, IsLoading, notify=changed)
  Selected = Property(bool, Selected, notify=changed)

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
  changed = Signal()
  Uid = Property(int, Uid, notify=changed)
  Date = Property(unicode, Date, notify=changed)
  From = Property(unicode, From, notify=changed)
  To = Property(unicode, To, notify=changed)
  CC = Property(unicode, CC, notify=changed)
  BCC = Property(unicode, BCC, notify=changed)
  Subject = Property(unicode, Subject, notify=changed)
  IsSent = Property(bool, IsSent, notify=changed)
  Read = Property(bool, Read, notify=changed)
  IsLoading = Property(bool, IsLoading, notify=changed)
  Selected = Property(bool, Selected, notify=changed)

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
  changed = Signal()
  FieldName = Property(unicode, FieldName, notify=changed)
  IsPassword = Property(bool, IsPassword, notify=changed)
  Value = Property(unicode, Value, notify=changed)
  Description = Property(unicode, Description, notify=changed)

class FilterButton(QObject):
  def __init__(self, name_, filterString_, isChecked_):
    QObject.__init__(self)
    self.name_ = name_
    self.filterString_ = filterString_
    self.isChecked_ = isChecked_
  def Name(self):
    return self.name_
  def FilterString(self):
    return self.filterString_
  def IsChecked(self):
    return self.isChecked_
  @Slot(bool)
  def setChecked(self, isChecked_):
    self.isChecked_ = isChecked_
    self.changed.emit()
  changed = Signal()
  Name = Property(unicode, Name, notify=changed)
  FilterString = Property(unicode, FilterString, notify=changed)
  IsChecked = Property(bool, IsChecked, notify=changed)

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
  @Slot(bool)
  def setShowing(self, showing_):
    self.showing_ = showing_
    self.changed.emit()
  changed = Signal()
  Text = Property(unicode, Text, notify=changed)
  Showing = Property(bool, Showing, notify=changed)
  HideDelay = Property(bool, HideDelay, notify=changed)

class Suggestion(QObject):
  def __init__(self, suggestionText_):
    QObject.__init__(self)
    self.suggestionText_ = suggestionText_
  def name(self):
    return self.suggestionText_
  changed = Signal()
  name = Property(unicode, name, notify=changed)

class MainWindow(QDeclarativeView):
  def __init__(self, qmlFile, controller,
    accountModel, folderModel, headerModel, configModel, filterButtonModel, notifierModel,
    addressBookModel, fileListModel):
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
    context.setContextProperty('controller', controller)
    context.setContextProperty('fileSystemController', controller.fileSystemController)

    self.setResizeMode(QDeclarativeView.SizeRootObjectToView)
    self.setSource(qmlFile)

class SendWindow(QDeclarativeView):
  def __init__(self, qmlFile, controller, main,
    accountModel, folderModel, headerModel, configModel, filterButtonModel, notifierModel,
    addressBookModel, fileListModel):
    super(SendWindow, self).__init__(None)
    context = self.rootContext()
    context.setContextProperty('main', main)
    context.setContextProperty('accountModel', accountModel)
    context.setContextProperty('folderModel', folderModel)
    context.setContextProperty('headerModel', headerModel)
    context.setContextProperty('configModel', configModel)
    context.setContextProperty('filterButtonModel', filterButtonModel)
    context.setContextProperty('notifierModel', notifierModel)
    context.setContextProperty('addressBookModel', addressBookModel)
    context.setContextProperty('fileListModel', fileListModel)
    context.setContextProperty('controller', controller)
    context.setContextProperty('fileSystemController', controller.fileSystemController)

    self.setResizeMode(QDeclarativeView.SizeRootObjectToView)
    self.setSource(qmlFile)

if __name__ == "__main__":
  sys.exit(main())
