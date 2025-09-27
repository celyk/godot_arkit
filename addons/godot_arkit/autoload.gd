@tool
extends Node

var xr_interface : ARKitInterface
const FeedRenderer = preload("renderer/feed_renderer.gd")
var feed_renderer := FeedRenderer.new()

func get_interface():
	return xr_interface

func _enter_tree():
	xr_interface = ARKitInterface.new()
	if xr_interface:
		XRServer.add_interface(xr_interface)
		print("ARKitInterface has been added to the XRServer")
		
		feed_renderer.initialize()
		
		CameraServer.monitoring_feeds = true
		CameraServer.add_feed(feed_renderer.feed)

func _process(delta: float) -> void:
	feed_renderer.render_feed()

func _exit_tree():
	if xr_interface:
		XRServer.remove_interface(xr_interface)
		xr_interface = null
		
		feed_renderer.cleanup()
