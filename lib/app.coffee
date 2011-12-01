###
Main wrapper module
###

OcrHost  = "cloud.ocrsdk.com"
AppId    = process.env.ABBYY_APPID
AppPass  = process.env.ABBYY_PWD
Port     = "443"

http      = require "http"
fs        = require "fs"
sys       = require "util"
xml2json  = require "xml2json"
url       = require "url"
#iconv     = require "iconv"

###
Class that implement api calls to abbyy cloud api.
###
class OCR
  constructor: (@appId=AppId, @appPass=AppPass) ->
    @version = "0.1.1"

  ###
  Create options, that passed to request object.

  @param {String} path Relative path, starting from "/"
  @param {"POST"|"GET"|"PUT"} method Http method
  @param {Object} headers Client headers, authorization will be added forcibly.
  @param {String} port Port :default "80"
  @param {String} host Hotsname :default "cloud.ocrsdk.com"
  @return {Object} options Options dict
  ###
  _createOptions: (path, method, headers={}, port="80", host=OcrHost) ->
    opts =
      host    : host
      port    : port
      path    : path
      method  : method
      headers : headers

    unless opts.headers.Authorization?
      opts.headers.Authorization = "Basic " + new Buffer("#{@appId}:#{@appPass}").toString "base64"
    opts

  ###
  Create options, that passed to request object.
  @see `_createOptions`

  @param {String} path Full path, starting from "http"
  @param {"POST"|"GET"|"PUT"} method Http method
  @param {Object} headers Client headers, authorization will be added forcibly.
  @return {Object} options Options dict
  ###
  _createOptionsFromUrl: (fullpath, method, headers) ->
    method   ||= "GET"
    parsedUrl  = url.parse fullpath
    port       = if parsedUrl.protocol is "https" then "443" else "80"
    @_createOptions parsedUrl.path, method, headers, port, parsedUrl.host


  ###
  Get binary data from server. This method is buggy.

  @param {Object} opts Request options, @see _createOptionsFromUrl
  @param {Function} fn Callback function, that accept 1) error (or null) 2) data.
  ###
  _getServerBinaryAnswer: (opts, fn) ->
    resData = new Buffer 10485760
    ind = 0
    req = http.request opts, (res) ->

      res.setEncoding "binary"
      res.on "data", (chunk) ->
        ind += resData.write(chunk, ind)
      res.on "end", ->
        fn null, resData
      res.on "error", (err) -> fn err
    req.end()


  ###
  Post/get data to server and retrieve answer.
  If opts method set to "GET", request will be sended authomatically, othervise, you need
  to forse request after calling this method by applying `res.end()`.

  @param {Object} opts Request options, @see _createOptionsFromUrl
  @param {Function} fn Callback function, that accept 1) error (or null) 2) data.
  @return {Object} req Request object, that can be used to post data and perform "post"/"put" requests.
  ###
  _getServerAnswer: (opts, fn) ->
    resData = ""
    req = http.request opts, (res) ->
      res.setEncoding "utf8"
      res.on "data", (chunk) ->
        resData += chunk
      res.on "end", ->
        fn null, resData
      res.on "error", (err) -> fn err
    if opts.method? and opts.method.toLowerCase() is "get"
      req.end()
    req

  ###
  For post purposes.
  ###
  _generateBoundary: ->
    "--------------------------------------------------#{Date.now()}--"


  # --------------------------------------------------------------------------------
  # public API
  # --------------------------------------------------------------------------------

  ###
  Get task status by task id.

  @param {String} taskId Task id
  @param {Function} fn Callback function, accept 1) error, 2) task status in json format
  ###
  getTaskStatus: (taskId, fn) ->
    getOpts =  @_createOptions "/getTaskStatus?taskId=#{taskId}", "get"
    @_getServerAnswer getOpts, (err, data) ->
      unless err
        try
          fn null, JSON.parse(xml2json.toJson data).response
        catch e
          fn msg: "can't parse status for task #{taskId}"
      else
        fn msg: "server error"


  ###
  Get list of tasks.

  @param {Function} fn Callback function, accept 1) error, 2) list of tasks in json format
  ###
  listTasks: (fn) ->
    getOpts = @_createOptions "/listTasks", "get"
    @_getServerAnswer getOpts, (err, data) ->
      unless err
        try
          fn null, JSON.parse(xml2json.toJson data).response
        catch e
          fn msg: "can't parse list of tasks"
      else
        fn msg: "server error"


  ###
  Apply ocr to file on local filesystem.

  @param {String} filename Absolute/relative path to file
  @param {Object|Function} opts Options, of function, see next param.
        opts.outputFormat - one of "txt", "rtf", "pdfSearchable", "docx", "xml"
        opts.lang  (String, Array of strings) - language, russian, english and maybe others
  @param {Function} fn Callback function, accept 1) error, 2) new task id
  ###
  applyToFile: (filename, opts, fn) ->
    if "function" is typeof opts
      fn    = opts
      opts  = null

    opts   ||= {}

    try
      buf = fs.readFileSync filename
      @applyToBuffer buf, opts, fn
    catch e
      fn msg: "can't read file #{filename}"

  ###
  Apply OCR conversion to buffer, containing image file.

  @param {Buffer} buffer Buffer with image
  @param {Object|Function} opts Options, of function, see next param.
        opts.outputFormat - one of "txt", "rtf", "pdfSearchable", "docx", "xml"
        opts.lang  (String, Array of strings) - language, russian, english and maybe others
  @param {Function} fn Callback function, accept 1) error, 2) new task id
  ###
  applyToBuffer: (buffer, opts={}, fn) ->
    opts.outputFormat ||= "txt"
    timeout = opts.requestTimeout || 1000 # 1 second
    opts.lang ||= ["russian", "english"]
    if opts.lang instanceof Array
      opts.lang = opts.lang.join ","

    boundary = @_generateBoundary()
    postOpts = @_createOptions  "/processImage?exportFormat=#{opts.outputFormat}&language=#{opts.lang}", "POST",
        {"Content-Type" : "multipart/form-data; boundary= #{boundary}"
        "Content-Length" : buffer.length}

    postReq = @_getServerAnswer postOpts, (err, data) ->
      unless err
        id = data.match /task id=\"[-a-f\d]+\"/ig
        if id
          fn null, id[0][9..-2]
        else
          msg = data.match /message .*\>.*\<\/message/ig
          if msg
            fn msg: msg[0].match(/\>.*\<\//ig)[0][1..-3]
          else
            fn msg: "unknown error"
      else
        fn err

    postReq.write buffer
    postReq.write boundary
    postReq.end()


  ###
  Get text content after OCR from specified url.

  @param {String} srcUrl Url with text content.
  @param {Function} fn Callback function, accept 1) error 2) dictionary with 2 fields: `resultUrl` and `text`
  ###
  getTextFromUrl: (srcUrl, fn) ->
    getOpts =  @_createOptionsFromUrl srcUrl, "GET", no
    delete getOpts.headers.Authorization

    @_getServerBinaryAnswer getOpts, (err, data) ->
      unless err
        try
          # conv = new iconv.Iconv "CP1251", "UTF8//IGNORE"
          # text = conv.convert(data).toString()
          fn null, resultUrl: srcUrl, text: data #text
        catch e
          fn msg: "error", resultUrl: srcUrl, error: e
      else
        fn msg: "error downloading file", resultUrl: srcUrl


  ###
  Wait till task end, then get url and content (for text data).

  @param {String} taskId Task id
  @param {Object|Function} opts Options, of function, see next param.
        opts.outputFormat - one of "txt", "rtf", "pdfSearchable", "docx", "xml"
        opts.lang  (String, Array of strings) - language, russian, english and maybe others
  @param {Function} fn Callback function, accept 1) error, 2) task object,
                contain resultUrl and (if opts.outputFormat is set to "txt") text fields.

  ###
  waitTaskEnd: (taskId, opts, fn) ->
    if "function" is typeof opts
      fn    = opts
      opts  = null

    opts   ||= {}
    timeout  = opts.timeout or 1000
    format   = opts.outputFormat or "txt"
    errors   = 0
    downloadInProcess = no

    nextTick = =>
      @getTaskStatus taskId, (err, status) =>
        unless downloadInProcess
          unless err
            if status?.task?.status?.toLowerCase() is "completed"
              downloadInProcess = yes
              resultUrl = status?.task?.resultUrl

              if resultUrl
                # if textual format, download txt or return url
                if format is "txt"
                  @getTextFromUrl resultUrl, fn
                else
                  fn null, {resultUrl: resultUrl}
            else if status?.task?.status?.toLowerCase() in ["queued" , "inprogress"]
              setTimeout ( => nextTick()), timeout
          else
            errors++
            if errors > 5
              fn msg: "error accessing document"
            else
              setTimeout ( => nextTick()), timeout
    nextTick()


exports.createWrapper = (appId, appPass) -> new OCR appId, appPass
