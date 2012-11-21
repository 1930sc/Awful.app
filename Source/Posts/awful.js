;(function(){
var Awful = {}
Awful.leftoverPosts = []

Awful.posts = function(posts){
  var firstUnseen = 0
  $.each(posts, function(i, post){
    if (!post.beenSeen) {
      firstUnseen = i
      return false
    }
  })
  
  Awful.leftoverPosts = posts.slice(0, firstUnseen)
  $('#posts').empty()
  
  $.each(posts.slice(firstUnseen), function(i, post){
    render(post).appendTo('#posts')
  })
  return Awful.leftoverPosts.length
}

Awful.insertPost = function(post, i){
  if (i < Awful.leftoverPosts.length) {
    Awful.leftoverPosts.splice(i, 0, post)
    return
  }
  i -= Awful.leftoverPosts.length
  if (i === 0) {
    render(post).prependTo('#posts')
  } else if (i >= $('#posts > article').length) {
    render(post).appendTo('#posts')
  } else {
    $('#posts > article').eq(i).before(render(post))
  }
}

Awful.deletePost = function(post, i){
  if (i < Awful.leftoverPosts.length) {
    Awful.leftoverPosts.splice(i, 1)
    return
  }
  i -= Awful.leftoverPosts.length
  $('#posts > article').eq(i).remove()
}

Awful.post = function(i, post){
  if (i < Awful.leftoverPosts.length) {
    Awful.leftoverPosts[i] = post
    return
  }
  i -= Awful.leftoverPosts.length
  $('#posts > article').eq(i).replaceWith(render(post))
}

Awful.invoke = function(selector, varargs){
  var stem = "x-objc:///" + selector + "/"
  var args = Array.prototype.slice.call(arguments, 1)
  window.location.href = stem + encodeURIComponent(JSON.stringify(args))
}

Awful.stylesheetURL = function(url){
  $('link').attr('href', url)
}

Awful.dark = function(dark){
  if (dark) $('body').addClass('dark')
  else $('body').removeClass('dark')
}

Awful.showAllPosts = function(){
  var firstAlreadyShown = $('#posts > article').first()
  var oldTop = firstAlreadyShown.offset().top
  $.each(Awful.leftoverPosts, function(i, post){
    render(post).insertBefore(firstAlreadyShown)
  })
  Awful.leftoverPosts.length = 0
  return firstAlreadyShown.offset().top - oldTop
}

Awful.ad = function(ad){
  $('#ad').html(ad)
}

Awful.loading = function(loading){
  if (nullOrUndefined(loading)) {
    $('#loading').hide().siblings('div').show()
  } else {
    $('#loading').show().siblings('div').hide()
    $('#loading p').text(loading)
  }
}

Awful.highlightQuoteUsername = function(username){
  Awful._highlightQuoteUsername = username
  if (nullOrUndefined(username)) {
    $('div.bbc-block.highlight').removeClass('highlight')
  } else {
    $('#posts > article > section').each(function(){
      highlightQuotes(this)
    })
  }
}

Awful.highlightMentionUsername = function(username){
  Awful._highlightMentionUsername = username
  if (nullOrUndefined(username)) {
    $('#posts > article > section span.highlight').each(function(){
      this.parentNode.replaceChild(this.firstChild, this)
      this.parentNode.normalize()
    })
  } else {
    $('#posts > article > section').each(function(){
      if ($(this).text().indexOf(username) != -1) highlightMentions(this)
    })
  }
}

Awful.showAvatars = function(on){
  Awful._showAvatars = !!on
  if (on) {
    $('#posts > article > header[data-avatar]').each(function(){
      $('<img>', { src: $(this).data('avatar'), alt: '' }).insertBefore($(this).children('button'))
      $(this).data('avatar', null)
      $(this).closest('article').removeClass('no-avatar')
    })
  } else {
    $('#posts > article > header > img').each(function(){
      hideAvatar($(this).closest('article'))
    })
  }
}

Awful.showImages = function(on){
  Awful._showImages = !!on
  if (on) {
    $('#posts > article > section a[data-awful="image"]').each(function(){
      $(this).replaceWith($('<img>', { src: $(this).text(), border: '0' }))
    })
  } else {
    $('#posts > article').each(function(){
      hideImages(this)
    })
  }
}

var baseURL = "http://forums.somethingawful.com/"

function render(post) {
  rendered = $('#postTemplate').mustache(post)
  rendered.find('a:not([href *= "://"])').each(function(){
    var a = $(this)
    a.attr('href', baseURL + a.attr('href'))
  })
  rendered.find('img:not([src *= "://"])').each(function(){
    var img = $(this)
    img.attr('src', baseURL + img.attr('src'))
  })
  if (!Awful._showAvatars) hideAvatar(rendered)
  if (!Awful._showImages) hideImages(rendered)
  highlightQuotes(rendered)
  highlightMentions(rendered)
  return rendered
}

function nullOrUndefined(arg) {
  return arg === null || arg === undefined
}

function highlightQuotes(post) {
  var username = Awful._highlightQuoteUsername
  if (nullOrUndefined(username)) return
  $(post).find('div.bbc-block a.quote_link').each(function(){
    if ($(this).text().indexOf(username) === 0) {
      $(this).closest('div.bbc-block').addClass('highlight')
    }
  })
}

function highlightMentions(post) {
  var username = Awful._highlightMentionUsername
  if (nullOrUndefined(username)) return
  eachTextNode($(post)[0], replaceAll)
  
  function eachTextNode(node, callback) {
    if (node.nodeType === Node.TEXT_NODE) callback(node)
    for (var i = 0, len = node.childNodes.length; i < len; i++) {
      eachTextNode(node.childNodes[i], callback)
    }
  }
  function replaceAll(node) {
    if ($(node.parentNode).filter('span.highlight').length > 0) return
    var i = node.data.indexOf(username)
    if (i === -1) return
    var nameNode = node.splitText(i)
    var rest = nameNode.splitText(username.length)
    var span = node.ownerDocument.createElement('span')
    span.className = 'highlight'
    span.appendChild(nameNode.cloneNode(true))
    node.parentNode.replaceChild(span, nameNode)
    replaceAll(rest)
  }
}

function regexEscape(s) {
  return s.replace(/[-\/\\^$*+?.()|[\]{}]/g, '\\$&')
}

function hideAvatar(post) {
  var img = $(post).find('header > img')
  if (img.length === 0) return
  img.closest('header').data('avatar', img.attr('src'))
  img.remove()
  $(post).addClass('no-avatar')
}

function hideImages(post) {
  $(post).children('section').find('img')
         .not('img[src*="://fi.somethingawful.com/images/smilies"]')
         .not('img[src*="://fi.somethingawful.com/safs/smilies"]')
         .not('img[src*="://i.somethingawful.com/images/emot"]')
         .not('img[src*="://i.somethingawful.com/forumsystem/emoticons"]')
         .each(function(){
    $(this).replaceWith($('<a data-awful="image"/>').text($(this).attr('src')))
  })
}

window.Awful = Awful
})()


;(function(){

$(function(){
  $('body').addClass($.os.ipad ? 'ipad' : 'iphone')
  
  $('#posts').on('tap', 'article > header > button', showPostActions)
  
  $('#posts').on('longTap', 'article > section img', previewImage)
  
  $('#posts').on('click', 'a[data-awful="image"]', showLinkedImage)
})

function showPostActions(e) {
  var button = $(e.target)
  var post = button.closest('article')
  var indexOfPost = post.index() + Awful.leftoverPosts.length
  var rect = button.offset()
  rect.left -= window.pageXOffset
  rect.top -= window.pageYOffset
  Awful.invoke("showActionsForPostAtIndex:fromRectDictionary:", indexOfPost, rect)
}

function previewImage(e) {
  Awful.invoke("previewImageAtURLString:", $(e.target).attr('src'))
}

function showLinkedImage(e) {
  var link = $(e.target)
  link.replaceWith($('<img border=0>').attr('src', link.text()))
  e.preventDefault()
}

})()
