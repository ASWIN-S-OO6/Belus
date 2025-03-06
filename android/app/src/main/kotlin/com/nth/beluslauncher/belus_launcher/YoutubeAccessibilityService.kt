package com.nth.beluslauncher

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class YouTubeAccessibilityService : AccessibilityService() {
    companion object {
        var currentVideoInfo: String? = null
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event?.packageName == "com.google.android.youtube") {
            println("Accessibility event received: ${event.eventType}")
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                // Try to find video URL (e.g., from share link or player)
                val urlNode = findNodeById(rootNode, "com.google.android.youtube:id/share_button")?.parent
                if (urlNode != null) {
                    currentVideoInfo = extractVideoUrl(urlNode)
                    if (currentVideoInfo != null) {
                        println("Detected video URL: $currentVideoInfo")
                        return
                    }
                }

                // Fallback to video title
                val titleNode = findNodeById(rootNode, "com.google.android.youtube:id/title")
                    ?: findNodeById(rootNode, "com.google.android.youtube:id/player_control_playback_title")
                    ?: findNodeByText(rootNode)
                currentVideoInfo = titleNode?.text?.toString()

                if (currentVideoInfo != null) {
                    println("Current YouTube video info: $currentVideoInfo")
                } else {
                    println("No video info found, dumping node tree for debugging:")
                    dumpNodeTree(rootNode, 0)
                }
            } else {
                println("Root node is null")
            }
        }
    }

    private fun findNodeById(node: AccessibilityNodeInfo, id: String): AccessibilityNodeInfo? {
        val nodes = node.findAccessibilityNodeInfosByViewId(id)
        return nodes.firstOrNull()
    }

    private fun findNodeByText(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (node.text != null && node.text.isNotEmpty() && node.text.length > 10) {
            return node
        }
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val found = findNodeByText(child)
            if (found != null) return found
        }
        return null
    }

    private fun extractVideoUrl(node: AccessibilityNodeInfo): String? {
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            val text = child.text?.toString()
            if (text != null && (text.contains("youtube.com/watch?v=") || text.contains("youtu.be/"))) {
                return text
            }
        }
        return null
    }

    private fun dumpNodeTree(node: AccessibilityNodeInfo, level: Int) {
        val indent = "  ".repeat(level)
        val text = node.text?.toString() ?: "null"
        println("$indent Node: ${node.className}, ID: ${node.viewIdResourceName}, Text: $text")
        for (i in 0 until node.childCount) {
            val child = node.getChild(i) ?: continue
            dumpNodeTree(child, level + 1)
        }
    }

    override fun onInterrupt() {
        println("Accessibility service interrupted")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                AccessibilityEvent.TYPE_VIEW_TEXT_CHANGED
        info.packageNames = arrayOf("com.google.android.youtube")
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_VISUAL
        info.notificationTimeout = 100
        info.flags = AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        this.serviceInfo = info
        println("Accessibility Service Connected")
    }
}