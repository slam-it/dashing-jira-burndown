class Dashing.Burndown extends Dashing.Canvasjs

  ready: ->
    @chart @get('container'), @get('data'), @get('title')

  onData: (data) ->
    @chart @get('container'), @get('data'), @get('title')
