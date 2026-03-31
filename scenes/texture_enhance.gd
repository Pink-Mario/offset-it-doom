extends TextureRect
class_name TextureEnhance

func play_flash_effect(duration: float = 0.3) -> void:
	var original_scale = scale
	var original_pivot = pivot_offset
	
	pivot_offset = size / 2.0
	
	var tween = create_tween()
	tween.set_parallel(true)

	tween.tween_property(self, "scale", original_scale * 2.0, duration)
	tween.tween_property(self, "modulate:a", 0.0, duration)

	tween.chain().tween_callback(queue_free)
	
