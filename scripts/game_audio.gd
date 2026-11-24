extends Node
## Efeitos sintetizados originais e ambiente local.
const RATE:int=22050
var samples:Dictionary={}
var voices:Array[AudioStreamPlayer]=[]
var ambience:Dictionary={}
var cooldown:Dictionary={}
var rng:=RandomNumberGenerator.new()
var effects_volume:float=0.65
var ambient_volume:float=0.35
var enabled:bool=true
var headless:bool=false
var clock:float=0.0
var ambient_timer:float=0.0

func _ready() -> void:
	headless=DisplayServer.get_name()=="headless"
	var config:=ConfigFile.new()
	if config.load("user://audio.cfg")==OK:
		enabled=bool(config.get_value("audio","enabled",true))
		effects_volume=clampf(float(config.get_value("audio","effects",0.65)),0,1)
		ambient_volume=clampf(float(config.get_value("audio","ambient",0.35)),0,1)
	if headless: return
	rng.seed=91731
	var presets:Dictionary={
		"ui":[720.0,0.07,0.08,220.0,0.30],
		"wood":[105.0,0.30,0.72,-70.0,0.65],
		"mine":[410.0,0.22,0.36,-180.0,0.55],
		"build":[165.0,0.15,0.55,-60.0,0.55],
		"forge":[850.0,0.38,0.30,-200.0,0.46],
		"pickup":[520.0,0.10,0.12,260.0,0.28],
		"deposit":[190.0,0.14,0.45,-70.0,0.32],
		"harvest":[360.0,0.17,0.75,-100.0,0.26],
		"fish":[320.0,0.23,0.75,-150.0,0.38],
		"cook":[480.0,0.20,0.9,-180.0,0.22],
		"hit":[125.0,0.13,0.70,-85.0,0.54],
		"sword":[960.0,0.23,0.44,-520.0,0.53],
		"shield":[270.0,0.24,0.42,-60.0,0.55],
		"bow":[350.0,0.16,0.60,-230.0,0.44],
		"magic":[330.0,0.65,0.12,650.0,0.48],
		"summon":[160.0,0.45,0.18,-80.0,0.46],
		"birth":[620.0,0.24,0.12,280.0,0.35],
		"death":[170.0,0.24,0.20,-105.0,0.25],
		"spawn":[560.0,0.19,0.16,420.0,0.36],
		"war":[150.0,0.70,0.09,65.0,0.46],
		"era":[440.0,0.55,0.04,440.0,0.40],
		"complete":[540.0,0.38,0.04,270.0,0.40],
		"animal_hurt":[210.0,0.16,0.24,-110.0,0.25],
		"chicken":[1050.0,0.22,0.15,-470.0,0.26],
		"duck":[240.0,0.22,0.30,-90.0,0.25],
		"frog":[115.0,0.28,0.12,-30.0,0.25],
		"bird":[1550.0,0.20,0.03,530.0,0.24],
		"animal":[270.0,0.25,0.15,-100.0,0.24],
		"growl":[70.0,0.38,0.50,-20.0,0.26]
	}
	for kind in presets.keys(): samples[kind]=_synth(str(kind),presets[kind])
	for i in range(6):
		var player:=AudioStreamPlayer.new()
		add_child(player)
		voices.append(player)
	for kind in ["water","wind","fire","swamp"]:
		var player:=AudioStreamPlayer.new()
		player.stream=_ambient_stream(kind)
		player.volume_db=-80
		add_child(player)
		ambience[kind]=player
		if enabled: player.play()

func _synth(kind:String,preset:Array) -> AudioStreamWAV:
	var freq:float=preset[0]
	var duration:float=preset[1]
	var noise_mix:float=preset[2]
	var sweep:float=preset[3]
	var amplitude:float=preset[4]
	var count:int=roundi(duration*RATE)
	var bytes:=PackedByteArray()
	bytes.resize(count*2)
	var phase:float=0.0
	var filtered:float=0.0
	for i in range(count):
		var t:float=float(i)/RATE
		var u:float=t/duration
		var f:float=maxf(35.0,freq+sweep*u)
		if kind in ["birth","complete","era"]: f=freq*(1.0 if u<0.35 else (1.25 if u<0.65 else 1.5))
		if kind in ["bird","chicken","frog","duck"]: f+=freq*0.13*sin(TAU*8*t)
		phase+=TAU*f/RATE
		filtered=lerpf(filtered,rng.randf_range(-1,1),0.36)
		var tone:float=sin(phase)*0.72+sin(phase*2.07)*0.19+sin(phase*3.13)*0.09
		if kind in ["forge","sword","shield","mine"]: tone=sin(phase)*0.5+sin(phase*2.71)*0.3+sin(phase*4.17)*0.2
		var envelope:float=minf(1.0,t/0.008)*pow(maxf(0,1.0-u),1.7)
		if kind in ["chicken","frog","duck"]: envelope*=0.45+0.55*absf(sin(TAU*5*t))
		var value:float=lerpf(tone,filtered,noise_mix)*envelope*amplitude
		bytes.encode_s16(i*2,roundi(clampf(value,-1,1)*32767))
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=RATE
	stream.data=bytes
	return stream

func _ambient_stream(kind:String) -> AudioStreamWAV:
	var count:int=RATE*4
	var bytes:=PackedByteArray()
	bytes.resize(count*2)
	var low:float=0.0
	var mid:float=0.0
	for i in range(count):
		var t:float=float(i)/RATE
		var u:float=float(i)/count
		var n:float=rng.randf_range(-1,1)
		low=lerpf(low,n,0.014)
		mid=lerpf(mid,n,0.20)
		var value:float=0.0
		match kind:
			"water": value=(mid*0.23+low*0.15)*(0.8+0.2*sin(TAU*u*3))
			"wind": value=low*(0.65+0.35*sin(TAU*u*2))
			"fire": value=mid*0.06+(n*0.20 if absf(n)>0.995 else 0.0)
			"swamp": value=low*0.20+sin(TAU*175*t+sin(TAU*u*4))*0.018*(0.5+0.5*sin(TAU*u*7))
		value*=minf(1.0,minf(u,1.0-u)*100.0)
		bytes.encode_s16(i*2,roundi(clampf(value,-1,1)*32767))
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate=RATE
	stream.data=bytes
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin=0
	stream.loop_end=count
	return stream

func _play(kind:String,level:float=1.0) -> void:
	if headless or not enabled or effects_volume<=0 or not samples.has(kind): return
	if clock<float(cooldown.get(kind,-1)): return
	for player in voices:
		if player.playing: continue
		player.stream=samples[kind]
		player.volume_db=linear_to_db(maxf(0.0001,effects_volume*level))
		player.pitch_scale=rng.randf_range(0.90,1.10) if kind!="ui" else 1.0
		player.play()
		cooldown[kind]=clock+(2.2 if kind in ["chicken","duck","frog","bird","animal","growl"] else (0.85 if kind in ["pickup","deposit","cook","harvest"] else 0.16))
		break

func play_ui() -> void:
	_play("ui",0.55)

func update_audio(world,center:Vector2,extent:Vector2,delta:float) -> void:
	clock+=delta
	if not enabled or headless:
		world.sound_events.clear()
		return
	var radius:float=maxf(3.0,minf(extent.x,extent.y)*0.72)
	var bounds:=Rect2(center-extent*0.5,extent)
	for event in world.sound_events:
		var pos:Vector2=event["position"]
		if not bounds.has_point(pos): continue
		var level:float=clampf(1.0-center.distance_to(pos)/radius,0.12,1.0)
		_play(str(event["kind"]),level)
	world.sound_events.clear()
	ambient_timer+=delta
	if ambient_timer<0.5: return
	ambient_timer=0
	var levels:Dictionary={"wind":0.55,"water":0.0,"fire":0.0,"swamp":0.0}
	for y in range(maxi(0,floori(center.y)-5),mini(world.tiles.size(),floori(center.y)+6)):
		for x in range(maxi(0,floori(center.x)-5),mini(world.tiles[y].size(),floori(center.x)+6)):
			var d:float=Vector2(x,y).distance_to(center)
			var strength:float=clampf(1-d/6,0,1)
			var kind:String=str(world.tiles[y][x])
			if kind=="water": levels["water"]=maxf(float(levels["water"]),strength)
			if kind=="swamp": levels["swamp"]=maxf(float(levels["swamp"]),strength)
	for site in world.sites:
		if str(site["kind"]) in ["campfire","oven","forge"]:
			var d:float=center.distance_to(Vector2(float(site["x"]),float(site["y"])))
			levels["fire"]=maxf(float(levels["fire"]),clampf(1-d/4,0,1))
	for kind in ambience.keys():
		var player:AudioStreamPlayer=ambience[kind]
		var target:float=ambient_volume*float(levels[kind])*0.65
		player.volume_db=lerpf(player.volume_db,linear_to_db(maxf(0.0001,target)),0.65)
		if not player.playing: player.play()

func _save_settings() -> void:
	var config:=ConfigFile.new()
	config.set_value("audio","enabled",enabled)
	config.set_value("audio","effects",effects_volume)
	config.set_value("audio","ambient",ambient_volume)
	config.save("user://audio.cfg")

func show_settings() -> void:
	var dialog:=AcceptDialog.new()
	dialog.title="Som do mundo"
	dialog.ok_button_text="Fechar"
	var body:=VBoxContainer.new()
	body.custom_minimum_size=Vector2(390,200)
	body.add_theme_constant_override("separation",12)
	var check:=CheckButton.new()
	check.text="Som ativado"
	check.button_pressed=enabled
	check.toggled.connect(func(value:bool) -> void:
		enabled=value
		if not enabled:
			for player in voices: player.stop()
			for player in ambience.values(): player.stop()
		_save_settings()
	)
	body.add_child(check)
	for kind in ["effects","ambient"]:
		var label:=Label.new()
		label.text="Efeitos sonoros" if kind=="effects" else "Ambiente"
		body.add_child(label)
		var slider:=HSlider.new()
		slider.min_value=0
		slider.max_value=1
		slider.step=0.05
		slider.value=effects_volume if kind=="effects" else ambient_volume
		slider.value_changed.connect(func(value:float) -> void:
			if kind=="effects": effects_volume=value
			else: ambient_volume=value
			_save_settings()
		)
		body.add_child(slider)
	dialog.add_child(body)
	add_child(dialog)
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered(Vector2i(440,280))
