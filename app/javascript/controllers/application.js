import "@hotwired/turbo-rails"

function scrollChatToBottom() {
  const messages = document.getElementById("messages")
  if (!messages) return

  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      messages.scrollTop = messages.scrollHeight
    })
  })
}

document.addEventListener("turbo:load", scrollChatToBottom)
document.addEventListener("turbo:render", scrollChatToBottom)
