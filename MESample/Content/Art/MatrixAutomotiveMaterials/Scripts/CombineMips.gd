@tool
extends EditorScript

func _run():
	# --- 配置路径 ---"res://Content/Art/MatrixAutomotiveMaterials/Textures/T_MESample_ll_Mip_0.hdr"
	var base_path = "res://Content/Art/MatrixAutomotiveMaterials/Textures/T_MESample_ll_Mip_" 
	var output_path = "res://Content/Art/MatrixAutomotiveMaterials/Textures/T_MESampleRadianceMap.tres"
	
	# 1. 读取 Level 0 (基准图)
	if not FileAccess.file_exists(base_path + "0.hdr"):
		print("错误: 找不到基准文件 ", base_path + "0.hdr")
		return
		
	var img_base = Image.load_from_file(base_path + "0.hdr")
	var w = img_base.get_width()
	var h = img_base.get_height()
	var fmt = img_base.get_format()
	
	print("基准尺寸: ", w, "x", h, " 格式ID: ", fmt)
	
	# 2. 计算需要多少级 Mipmap 才能填满 (一直到 1x1)
	# 公式: floor(log2(max(w, h))) + 1
	var mip_levels = int(floor(log(max(w, h)) / log(2))) + 1
	print("需要填充的 Mipmap 层级总数: ", mip_levels)
	
	# 准备一个大的字节数组来存放所有数据
	var combined_data = PackedByteArray()
	
	# 用于生成缺失层级的临时变量
	var prev_img: Image = null
	
	# 3. 循环构建每一层的数据
	for i in range(mip_levels):
		var current_img: Image = null
		var file_path = base_path + str(i) + ".hdr"
		
		# A. 尝试从硬盘加载 (对应你的 0, 1, 2, 3, 4)
		if FileAccess.file_exists(file_path):
			current_img = Image.load_from_file(file_path)
			# 确保格式一致 (防止 Python 生成的个别图格式变异)
			if current_img.get_format() != fmt:
				current_img.convert(fmt)
			print("Level ", i, ": 从文件加载成功")
			
		# B. 如果文件不存在 (对应 5, 6, 7...)，则把上一级缩小一半生成
		elif prev_img != null:
			current_img = prev_img.duplicate()
			# 计算目标尺寸
			var target_w = max(1, w >> i) # 右移位运算等于除以 2^i
			var target_h = max(1, h >> i)
			current_img.resize(target_w, target_h, Image.INTERPOLATE_BILINEAR)
			print("Level ", i, ": 自动生成 (", target_w, "x", target_h, ")")
			
		else:
			print("错误: Mipmap 链在 Level ", i, " 断裂，且无法修复。")
			return
		
		# 将当前层级的二进制数据追加到总数组
		combined_data.append_array(current_img.get_data())
		
		# 记录下来供下一轮缩放使用
		prev_img = current_img

	# 4. 一次性创建最终的 Image
	# 注意：create_from_data 是静态方法
	var final_image = Image.create_from_data(w, h, true, fmt, combined_data)
	
	if final_image:
		# 创建纹理并保存
		var texture = ImageTexture.create_from_image(final_image)
		ResourceSaver.save(texture, output_path)
		print("---------------------------------------")
		print("成功！已保存资源到: ", output_path)
		print("请在 Shader 中使用 textureLod(tex, uv, roughness * 4.0) 采样")
	else:
		print("错误: 创建 Image 失败，可能是数据长度不匹配。")
