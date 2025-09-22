@tool
extends Node

var xr_interface : ARKitInterface

func get_interface():
	return xr_interface

func _enter_tree():
	xr_interface = ARKitInterface.new()
	if xr_interface:
		XRServer.add_interface(xr_interface)
		print("ARKitInterface has been added to the XRServer")


func _exit_tree():
	if xr_interface:
		XRServer.remove_interface(xr_interface)
		xr_interface = null
