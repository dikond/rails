# Encapsulate the cable connection held by the consumer. This is an internal class not intended for direct user manipulation.
class Cable.Connection
  @reopenDelay: 500

  constructor: (@consumer) ->
    @open()

  send: (data) ->
    if @isOpen()
      @webSocket.send(JSON.stringify(data))
      true
    else
      false

  open: =>
    if @webSocket and not @isState("closed")
      throw new Error("Existing connection must be closed before opening")
    else
      @webSocket = new WebSocket(@consumer.url)
      @installEventHandlers()
      true

  close: ->
    @webSocket?.close()

  reopen: ->
    if @isState("closed")
      @open()
    else
      try
        @close()
      finally
        setTimeout(@open, @constructor.reopenDelay)

  isOpen: ->
    @isState("open")

  # Private

  isState: (states...) ->
    @getState() in states

  getState: ->
    return state.toLowerCase() for state, value of WebSocket when value is @webSocket?.readyState
    null

  installEventHandlers: ->
    for eventName of @events
      handler = @events[eventName].bind(this)
      @webSocket["on#{eventName}"] = handler

  events:
    message: (event) ->
      {identifier, message} = JSON.parse(event.data)
      @consumer.subscriptions.notify(identifier, "received", message)

    open: ->
      @disconnected = false
      @consumer.subscriptions.reload()

    close: ->
      @disconnect()

    error: ->
      @disconnect()

  disconnect: ->
    return if @disconnected
    @disconnected = true
    @consumer.subscriptions.notifyAll("disconnected")

  toJSON: ->
    state: @getState()
