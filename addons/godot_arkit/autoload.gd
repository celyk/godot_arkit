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

var _initialized := false
func _process(delta: float) -> void:
	
	var imgs : Array[Image] = xr_interface.get_image_planes()
	
	if imgs.is_empty(): return
	
	imgs[0].convert(Image.Format.FORMAT_RGBA8)
	imgs[1].convert(Image.Format.FORMAT_RGBA8)
	
	feed_renderer.images = imgs
	
	if not _initialized: 
		feed_renderer._RD = RenderingServer.get_rendering_device()
		
		var resolution = imgs[0].get_size()
		resolution.x = max(resolution.x, imgs[1].get_size().x)
		resolution.y = max(resolution.y, imgs[1].get_size().y)
		
		feed_renderer.set_feed_size(resolution)
		
		CameraServer.monitoring_feeds = true
		
		feed_renderer.initialize()
		
		CameraServer.add_feed(feed_renderer.feed)
		
		_initialized = true
		return
	
	feed_renderer.render_feed()

func _exit_tree():
	if xr_interface:
		XRServer.remove_interface(xr_interface)
		xr_interface = null
		
		feed_renderer.cleanup()
