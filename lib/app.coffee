###
Main wrapper module
###

OcrHost  = "cloud.ocrsdk.com"
AppId    = process.env.ABBYY_APPID || "app-id-here"
AppPass  = process.env.ABBYY_PWD || "app-passwd-here"
Port     = "443"

http      = require "http"
fs        = require "fs"
sys       = require "util"
xml2json  = require "xml2json"
url       = require "url"


class OCR

  _createOptions: (path, method, headers={}, port="80", host=OcrHost) ->
    opts =
      host    : host
      port    : port
      path    : path
      method  : method
      headers : headers

    unless opts.headers.Authorization?
      opts.headers.Authorization = "Basic " + new Buffer("#{AppId}:#{AppPass}").toString "base64"
    opts

  _createOtionsFromUrl: (fullpath, method, headers) ->
    method   ||= "GET"
    parsedUrl  = url.parse fullpath
    port       = if parsedUrl.protocol is "https" then "443" else "80"
    @_createOptions parsedUrl.path, method, headers, port, parsedUrl.host


  _getServerAnswer: (opts, fn) ->
    resData = ""
    req = http.request opts, (res) ->
      unless opts.noEncoding
        res.setEncoding "utf8"
      res.on "data", (chunk) ->
        resData += chunk
      res.on "end", ->
        fn null, resData
      res.on "error", (err) -> fn err
    if opts.method? and opts.method.toLowerCase() is "get"
      req.end()
    req

  _generateBoundary: ->
    "--------------------------------------------------#{Date.now()}--"


  # --------------------------------------------------------------------------------
  # api wrapper
  # --------------------------------------------------------------------------------

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


  applyToFile: (filename, opts={}, fn) ->
    try
      buf = fs.readFileSync filename
      @applyToBuffer buf, opts, fn
    catch e
      fn msg: "can't read file #{filename}"

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
                  getOpts =  @_createOtionsFromUrl resultUrl, "GET", no
                  delete getOpts.headers.Authorization
                  getOpts.noEncoding = yes
#                  console.log "\n\nGO = #{sys.inspect getOpts}"
                  @_getServerAnswer getOpts, (err, data) ->
                    unless err
                      try
                        conv = new iconv.Iconv "windows-1251", "utf8"
                        body = conv.convert(new Buffer(data, 'binary')).toString()
                        fn null, resultUrl: resultUrl, text: body
                      catch e
                        fn msg: "error", resultUrl: resultUrl
                    else
                      fn msg: "error downloading file", resultUrl: resultUrl
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


exports.createWrapper = ->  new OCR()

