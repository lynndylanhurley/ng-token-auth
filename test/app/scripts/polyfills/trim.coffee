unless String.prototype.trim
  String.prototype.trim = ->
    this.replace(/^[\s\xA0]+|[\s\xA0]+$/g, '')
