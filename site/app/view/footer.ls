B = require \backbone
F = require \fs # inlined by brfs
H = require \../helper

module.exports = B.View.extend do
  initialize: ->
    H.insert-css F.readFileSync __dirname + \/footer.css
    @T = F.readFileSync __dirname + \/footer.html

  render: ->
    @$el.html @T .show!
    attach \facebook-jssdk, '//connect.facebook.net/en_GB/sdk.js#xfbml=1&appId=1655165271375218&version=v2.0'
    attach \twitter-wjs   , '//platform.twitter.com/widgets.js'

    function attach id, url
      fjs = (d = document).getElementsByTagName(\script)[0]
      return if d.getElementById id
      js = d.createElement \script
        ..id  = id
        ..src = url
      fjs.parentNode.insertBefore js, fjs
