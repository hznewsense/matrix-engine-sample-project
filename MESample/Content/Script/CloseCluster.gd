extends Button

var flag = true

func _on_pressed() -> void:
	if flag:
		$"../../../../../ClusterViewport".set_update_mode(SubViewport.UPDATE_ALWAYS)
		flag = !flag
		CommandTool.print_to_screen(get_viewport(),"AAAAAAAAAAAAAAA:render rt")
	else:
		$"../../../../../ClusterViewport".set_update_mode(SubViewport.UPDATE_DISABLED)
		flag = !flag
		CommandTool.print_to_screen(get_viewport(),"BBBBBBBBBBBBBBB: do not render rt")
		
	pass # Replace with function body.


func _on_button_2_pressed() -> void:
	$"../../../../../ClusterViewport".set_size(Vector2i(1920,1080))
	CommandTool.print_to_screen(get_viewport(),"CCCCCCCCCCCCCCCCC: 1920")
	
	pass # Replace with function body.

#960*540
func _on_button_3_pressed() -> void:
	$"../../../../../ClusterViewport".set_size(Vector2i(960,540))
	CommandTool.print_to_screen(get_viewport(),"CCCCCCCCCCCCCCCCC: 960")
	pass # Replace with function body.
