node-ocr обертка для ABBYY Cloud API ( [http://ocrsdk.com/](http://ocrsdk.com/) ).
==================================================================================

# Установка

  Работает с nodejs 0.6.x.
  

```
        npm install node-ocr
```

# Использование

## Создать объект для доступа к api


```coffee-script
        ocr = require("node-ocr").createWrapper(appId, appPwd)
```

`appId` и `appPwd` - опциональные параметы, если не заданы, идентификатор и пароль 
беруться из переменных окружения `ABBYY_APPID` и `ABBYY_PWD` соответственно.


## Получить список заданий

Обработчик получает состояние `err` и список заданий `taskList` - объект, содержащий
ключ task, значением которого является массив заданий.

```coffee-script
        ocr.listTasks (err, tasksList) ->
          unless err
            console.dir(tasksList)
```

## Обработать файл с изображением

Передаваемые параметры: путь к файлу, опции, обработчик.

Обработчик получает состояние `err` и идентификатор задания `id`.

```coffee-script
        ocr.applyToFile "/tmp/filename.jpeg", {outputFormat: "rtf"}, (err, id) ->
          unless err
            console.log "task id = #{id}"
```

## Обработать буфер с изображением

Передаваемые параметры: буфер, опции, обработчик.

Обработчик получает состояние `err` и идентификатор задания `id`.

```coffee-script
        ocr.applyToBuffer buffer, {outputFormat: "xml"}, (err, id) ->
          unless err
            console.log "task id = #{id}"
```


## Получить состояние задачи

Передаваемые параметры: идентификатор задачи и обработчик.

Обработчик получает состояние `err` и объект статуса (`stat`), содержащий ключ task.

```coffee-script
        ocr.getTaskStatus taskId, (err, stat) ->
          unless err
            console.dir(stat.task)

```

## Дождаться выполнения задачи

Передаваемые параметры: идентификатор задачи, опции, обработчик.

Обработчик получает состояние `err` и объект с ключом resultUrl, содержащим путь к обработанному файлу.

```coffee-script
        ocr.waitTaskEnd id, opts, (err, data) ->
          unless err
            console.dir(data.resultUrl)
```

## Получить текст по адресу

   Сейчас эта функция не работает, потому что текст возвращается в cp1251.



# Примеры использования

## Coffee-script

```coffee-script
        sys = require "util"
        ocr = require("node-ocr").createWrapper()


        opts      = outputFormat: "xml"
        filename  = "/tmp/filewithtext.png"

        ocr.applyToFile filename, opts, (err, id) ->
            unless err
              ocr.waitTaskEnd id, opts, (err, data) ->
                console.log "what we got: #{sys.inspect data, null, null}"
            else
              console.log "Error found: #{sys.inspect err}"

        # ... проверить задания
        ocr.listTasks (err, data) ->
            unless err
                   console.log "fetch data:\n#{sys.inspect data, null, null}"
            else
                   console.log "error :\n#{sys.inspect err}"

```    




## Javascript

```javascript
        sys = require("util")
        ocr = require("node-ocr").createWrapper()

        opts      = {outputFormat: "txt"}  # с русским текстом пока проблемы
        filename  = "/tmp/filewithtext.png"

        ocr.applyToFile(filename, opts, function (err, id) {
            if (null === err) {
              ocr.waitTaskEnd(id, opts, function (err, data) {
                console.log("what we got: " + sys.inspect( data, null, null));
                });
            } else {
              console.log("Error found: " + sys.inspect(err));
              }
            });
        # ... проверить задания
        ocr.listTasks( function (err, data) {
            if (null === err) {
                   console.log("fetch data:\n" + sys.inspect(data, null, null));
            } else {
                   console.log("error :\n#" + sys.inspect(err));
            }
         })
```   

# Changelog

## v 0.1.1
   - Ключи API можно изменить при вызове `createWrapper`

## v 0.1.0

   - Загрузка изображений
   - Состояние задачи обработки
   - Ожидание конца обработки
