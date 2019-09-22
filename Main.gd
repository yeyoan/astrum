extends Node

export (PackedScene) var Planet
export (PackedScene) var Spike

const MAX_MULTIPLIER: int = 8
const MAX_ENEMIES: int = 20

var active := false

onready var Spark = load("res://Spark.tscn")
onready var ScoredPopup = load("res://ScoredPopup.tscn")

var score: int = 0
var high_score: int = 0
var multiplier: int = 1
var health: float = 100
var music_on: bool = true
var sfx_on: bool = true
var enemies_spawned: int = 0
var combo: bool = false

# HACK: prevent button sound from playing when first loading game. 
var init_load: int = 2


onready var sfx: Dictionary = {
    "black_hole_active": $BlackHoleActiveSound,
    "black_hole_transition": $BlackHoleTransitionSound,
    "hit": $HitSound,
    "bounce": $BounceSound,
    "button": $ButtonSound    
}


func _ready() -> void:
    randomize()
    load_game()    
    $AmbientSound.play()
    $HUD.hide_high_score(true)
    _reset_achievements()


func _process(delta: float) -> void:
    if active:
        _update_health(health - (10 if $Player.moving else 30) * delta)
    
    if round(health) == 0:
        $BlackHole.disappear()
        $Player.disappear()
        _game_over()


func save() -> Dictionary:
    return {
        "high_score" : high_score,
        "music_on": music_on,
        "sfx_on": sfx_on
    }


func save_game() -> void:
    var save_game := File.new()
    save_game.open("user://savegame.save", File.WRITE)
    save_game.store_line(to_json(save()))
    save_game.close()
    
    
func load_game() -> void:
    var save_game = File.new()
    if not save_game.file_exists("user://savegame.save"):
        return
    
    save_game.open("user://savegame.save", File.READ)
    var line = parse_json(save_game.get_line())
    _update_high_score(line["high_score"])
    _set_sfx_on(line["sfx_on"])
    _set_music_on(line["music_on"])
    save_game.close()


func new_game() -> void:
    enemies_spawned = 0
    _enable_background_blur(false)
    _play_sfx("button")
    _update_score(0)
    _update_health(100)
    _update_multiplier(0)
    $HUD.hide_high_score(score >= high_score)
    $StartTimer.start()
    $Player.start()
    $Tween.start()
    _dampen_sfx(false)
    _dampen_ambient_music(false)
    
    
func _play_sfx(key: String) -> void:
    sfx.get(key).play()
        
        
func _stop_sfx(key: String) -> void:
    sfx.get(key).stop()
    
    
func _reset_achievements() -> void:
    """ These achievements must be completed in one round """
    $HUD.reset_achievement("score10Points")    
    $HUD.reset_achievement("score100Points")
    $HUD.reset_achievement("score1000Points")
    
    
func _game_over() -> void:
    $HUD.show_game_over()
    _enable_background_blur(true, 0)    
    active = false
    _dampen_sfx(true)
    _dampen_ambient_music(true)
    
    $HUD.increment_achievement("stella_mortem", 1)
    
    # These achievements must be completed in one round
    _reset_achievements()

    
func scored(special: bool, position: Vector2) -> void:
    if not active:
        return
        
    var points = (2 if special else 1) * (multiplier if multiplier != 0 else 1)
    $HUD.increment_achievement("score10Points", points)
    $HUD.increment_achievement("score100Points", points)
    $HUD.increment_achievement("score1000Points", points)
    
    _update_health(health + (30 if special else 10))
    enemies_spawned -= 1
    combo = true
    Engine.time_scale = 0.125
    _update_score(score + points)
    _update_multiplier(multiplier + 1)
    if multiplier == 5:
        $HUD.increment_achievement("sequentia", 1)
    $ComboTimer.start()
    if score > high_score:
        $HUD.hide_high_score(true)
        _update_high_score(score)
        save_game()

    _play_sfx("hit")
    _play_sfx("bounce")
    var popup = ScoredPopup.instance()
    add_child(popup)
    popup.display(position, points)
    
    _add_spark(Palette.PINK if special else Palette.ORANGE, position)
    
    
func _add_spark(color: Color, position: Vector2) -> void:
    var spark = Spark.instance()
    add_child(spark)
    spark.set_color(color)
    spark.set_position(position)
    spark.set_emitting(true)
    yield(get_tree().create_timer(6), "timeout")
    spark.queue_free()
    

func _update_score(value: int) -> void:
    score = value
    $HUD.update_score(score)


func _update_high_score(value: int) -> void:
    high_score = value
    $HUD.update_high_score(high_score)


func _update_health(value: float) -> void:
    if value < 0 or value > 100:
        return 
    health = value
    $HUD.update_health_bar(health)


func _update_multiplier(value: int) -> void:
    if value <= MAX_MULTIPLIER:
        multiplier = value
        $HUD.update_multiplier(multiplier)
    
    
func _set_sfx_on(value: bool) -> void:
    $HUD.set_sfx_on(value)
    
    
func _set_music_on(value: bool) -> void:
    $HUD.set_music_on(value)
    

func _get_random_position() -> Vector2:
    randomize()
    var x = $Player.position.x + $Player.direction.x + rand_range(100, 300)
    var y = $Player.position.y + $Player.direction.y + rand_range(100, 300)
    return Vector2(x, y)


func _on_PlanetTimer_timeout() -> void:
    if active and $Player.moving and enemies_spawned <= MAX_ENEMIES:
        enemies_spawned += 1
        var planet = Planet.instance()
        add_child(planet)
        planet.appear(_get_random_position())
        if planet.connect("scored", self, "scored"):
            pass
        if planet.connect("disappeared", self, "_planet_disappeared"):
            pass
        if $HUD.connect("start_game", planet, "_on_start_game"):
            pass


func _planet_disappeared() -> void:
    enemies_spawned -= 1


func _on_StartTimer_timeout():
    active = true    
    $PlanetTimer.start()
    $BlackHoleTimer.start()
    $SpikeTimer.start()


func _on_BlackHole_absorb() -> void:
    $BlackHole.disappear()
    $Player.disappear()
    _game_over()


func _dampen_ambient_music(yes: bool) -> void:
    AudioServer.set_bus_effect_enabled(1, 0, yes)


func _dampen_sfx(yes: bool) -> void:
    AudioServer.set_bus_effect_enabled(3, 0, yes)
    

func _on_BlackHoleTimer_timeout() -> void:
    if active and $Player.moving:
        $HUD.disable_warning(false)
        yield(get_tree().create_timer(1), "timeout")
        _play_sfx("black_hole_transition")
        _play_sfx("black_hole_active")
        $BlackHole.appear(_get_random_position())
    else:
        $BlackHoleTimer.start()


func _on_BlackHole_inactive() -> void:
    _stop_sfx("black_hole_active")
    if active and $Player.moving:
        _play_sfx("black_hole_transition")
        $BlackHoleTimer.set_wait_time(rand_range(2, 4))
        $BlackHoleTimer.start()
        $HUD.disable_warning(true)
        

func _enable_background_blur(yes: bool, layer: int = -2) -> void:
    $Tween.interpolate_property(
        $ParallaxBackground/ParallaxLayer/BlurLayer/Blur.material,
        "shader_param/blurSize",
        $ParallaxBackground/ParallaxLayer/BlurLayer/Blur.material.get_shader_param("blurSize"),
        20 if yes else 0,
        0.2,
        Tween.TRANS_QUAD,
        Tween.EASE_OUT
    )
    $Tween.start()
    $ParallaxBackground/ParallaxLayer/BlurLayer.layer = layer
    $MainModulate.visible = layer == 0
    $ParallaxForeground/ParallaxLayer/ForegroundModulate.visible = layer == 0
    $ParallaxBackground/ParallaxLayer/BackgroundModulate.visible = layer == 0


func _on_Comet_slo_mo(temporary: bool = true) -> void:
    Engine.time_scale = 0.25
    _enable_background_blur(true)
    if temporary:
        $SlowMotionTimer.start()


func _on_Comet_nor_mo() -> void:
    _play_sfx("bounce")
    Engine.time_scale = 1
    _enable_background_blur(false)
    print('here')
    if combo:
        combo = false
    else:
        _reset_combo()
        
        
func _reset_combo() -> void:
    _update_multiplier(0)


func on_Player_destroyed(player_position: Vector2) -> void:
    _play_sfx("hit")
    _add_spark(Palette.BLUE, player_position)    
    _game_over()


func _on_SpikeTimer_timeout() -> void:
    if active and $Player.moving:
        var spike = Spike.instance()
        add_child(spike)
        spike.position = _get_random_position()
        if spike.connect("destroyed_player", self, "on_Player_destroyed"):
            pass
        if $HUD.connect("start_game", spike, "_on_start_game"):
            pass


func _on_ComboTimer_timeout() -> void:
    _reset_combo()


func _on_SlowMotionTimer_timeout() -> void:
    Engine.time_scale = 1
    if active:
        $Tween.interpolate_property($ParallaxBackground/ParallaxLayer/BlurLayer/Blur.material, "shader_param/blurSize", $ParallaxBackground/ParallaxLayer/BlurLayer/Blur.material.get_shader_param("blurSize"), 0, 0.2, Tween.TRANS_QUAD, Tween.EASE_OUT)
        $Tween.start()


func _on_HUD_sfx_toggled() -> void:
    sfx_on = not sfx_on
    AudioServer.set_bus_mute(3, not sfx_on)
    AudioServer.set_bus_mute(2, not sfx_on)
    
    # HACK: read explanation above init_load declaration    
    if init_load == 0:
        _play_sfx("button")
    else:
        init_load -= 1
    save_game()    
        

func _on_HUD_music_toggled() -> void:
    music_on = not music_on
    AudioServer.set_bus_mute(1, not music_on)
    
    # HACK: read explanation above init_load declaration
    if init_load == 0:
        _play_sfx("button")
    else:
        init_load -= 1
    save_game()        
