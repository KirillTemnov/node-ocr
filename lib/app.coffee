###
Main wrapper module
###

OcrHost = "cloud.ocrsdk.com"
AppId = process.env.ABBYY_APPID || "app-id-here"
AppPass = process.env.ABBYY_PWD || "app-passwd-here"

http = require "http"
fs = require "fs"
sys = require "util"

class OCR
  constructor: ->
    @auth = null

  _createOptions: (path, method, headers={}, port="80") ->
    opts =
      host: OcrHost
      port: port
      path: path
      method: method
      headers: headers
    unless opts.headers.Authorization?
      opts.headers.Authorization = "Basic " + new Buffer("#{AppId}:#{AppPass}").toString "base64"
    opts

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

  _generateBoundary: ->
    "--------------------------------------------------#{Date.now()}--"


  # --------------------------------------------------------------------------------
  # api wrapper
  # --------------------------------------------------------------------------------

  getTaskStatus: (taskId) ->
    getOpts =  @_createOptions "/getTaskStatus?taskId=#{taskId}", "get"
    @_getServerAnswer getOpts, (err, data) ->
      unless err
        console.log "data = #{data}"
      else
        console.log "err = #{err}"


  listTasks: ->
    getOpts = @_createOptions "/listTasks", "get"
    @_getServerAnswer getOpts, (err, data) ->
      unless err
        console.log "data = #{data}"
      else
        console.log "err = #{err}"


  applyToFile: (filename, opts={}, fn) ->
    try
      buf = fs.readFileSync filename
      @applyToBuffer buf, opts, fn
    catch e
      console.log "exception #{e}"
      fn msg: "can't read file #{filename}"

  applyToBuffer: (buffer, opts={}, fn) ->
    opts.output ||= "txt"
    opts.lang ||= ["russian", "english"]
    if opts.lang instanceof Array
      opts.lang = opts.lang.join ","

    boundary = @_generateBoundary()
    postOpts = @_createOptions  "/processImage?exportFormat=#{opts.output}&language=#{opts.lang}", "POST",
        {"Content-Type" : "multipart/form-data; boundary= #{boundary}"
        "Content-Length" : buffer.length}

    postReq = @_getServerAnswer postOpts, (err, data) ->
      unless err
        console.log "data = #{data}"
        id = data.match /task id=\"[-a-f\d]+\"/ig
        if id
          fn null, id[0][10..-2]
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

exports.ocr = OCR
