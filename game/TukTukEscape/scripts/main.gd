extends Node3D

var player: CharacterBody3D
var camera: Camera3D
var health := 100
var money := 0
var mission_done := false
var ui_label: Label
var joystick_center := Vector2.ZERO
var joystick_active := false
var joystick_vector := Vector2.ZERO

func _ready():
    _make_environment()
    _make_player()
    _make_ui()

func _make_environment():
    var world_env = WorldEnvironment.new()
    var env = Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.48, 0.65, 0.82)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.75, 0.78, 0.82)
    env.ambient_light_energy = 0.8
    world_env.environment = env
    add_child(world_env)

    var sun = DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -25, 0)
    sun.light_energy = 1.2
    add_child(sun)

    _box("Ground", Vector3(0,-0.55,0), Vector3(70,1,70), Color(0.22,0.28,0.22))
    _box("Road1", Vector3(0,0,0), Vector3(12,0.08,70), Color(0.08,0.09,0.1))
    _box("Road2", Vector3(0,0,0), Vector3(70,0.08,12), Color(0.08,0.09,0.1))

    for z in range(-30, 31, 6):
        _box("RoadMark", Vector3(0,0.06,z), Vector3(0.35,0.03,3.0), Color(0.95,0.85,0.25))
    for x in range(-30, 31, 6):
        _box("RoadMark", Vector3(x,0.06,0), Vector3(3.0,0.03,0.35), Color(0.95,0.85,0.25))

    var buildings = [
        [Vector3(-22,4,-22), Vector3(10,8,10)],
        [Vector3(22,5,-22), Vector3(12,10,9)],
        [Vector3(-22,3,22), Vector3(9,6,12)],
        [Vector3(22,4,22), Vector3(11,8,11)],
        [Vector3(-28,2,-5), Vector3(7,4,9)],
        [Vector3(28,3,6), Vector3(7,6,10)]
    ]
    for b in buildings:
        _box("Building", b[0], b[1], Color(0.35 + randf()*0.2, 0.3 + randf()*0.15, 0.25 + randf()*0.15))

    for p in [Vector3(-6,0,8), Vector3(7,0,-9), Vector3(9,0,9), Vector3(-9,0,-8)]:
        _make_car(p)

    for p in [Vector3(10,0,4), Vector3(-8,0,-5), Vector3(4,0,15)]:
        _make_coin(p)

func _box(n:String, pos:Vector3, size:Vector3, mat_color:Color):
    var body = StaticBody3D.new()
    body.name = n
    body.position = pos
    var mesh = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = size
    mesh.mesh = box
    var mat = StandardMaterial3D.new()
    mat.albedo_color = mat_color
    mesh.material_override = mat
    body.add_child(mesh)
    var col = CollisionShape3D.new()
    var shape = BoxShape3D.new()
    shape.size = size
    col.shape = shape
    body.add_child(col)
    add_child(body)

func _make_car(pos:Vector3):
    var car = Node3D.new()
    car.position = pos
    add_child(car)
    var body = MeshInstance3D.new()
    var box = BoxMesh.new()
    box.size = Vector3(2.2,0.9,4.0)
    body.mesh = box
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.75,0.12+randf()*0.2,0.08)
    body.material_override = mat
    body.position.y = 0.5
    car.add_child(body)
    for x in [-0.9,0.9]:
        for z in [-1.35,1.35]:
            var wheel = MeshInstance3D.new()
            var cyl = CylinderMesh.new()
            cyl.top_radius = 0.35
            cyl.bottom_radius = 0.35
            cyl.height = 0.25
            wheel.mesh = cyl
            wheel.rotation_degrees.z = 90
            wheel.position = Vector3(x,0.35,z)
            car.add_child(wheel)

func _make_coin(pos:Vector3):
    var a = Area3D.new()
    a.position = pos + Vector3(0,1,0)
    a.set_meta("coin", true)
    var mesh = MeshInstance3D.new()
    var cyl = CylinderMesh.new()
    cyl.top_radius = 0.35
    cyl.bottom_radius = 0.35
    cyl.height = 0.12
    mesh.mesh = cyl
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(1.0,0.75,0.05)
    mesh.material_override = mat
    a.add_child(mesh)
    var cs = CollisionShape3D.new()
    var sh = CylinderShape3D.new()
    sh.radius = 0.45
    sh.height = 1.0
    cs.shape = sh
    a.add_child(cs)
    a.body_entered.connect(_coin_entered.bind(a))
    add_child(a)

func _coin_entered(body, coin):
    if body == player and is_instance_valid(coin):
        money += 10
        coin.queue_free()
        _update_ui()

func _make_player():
    player = CharacterBody3D.new()
    player.name = "Player"
    player.position = Vector3(0,0.6,18)
    add_child(player)

    var mesh = MeshInstance3D.new()
    var capsule = CapsuleMesh.new()
    capsule.height = 1.8
    capsule.radius = 0.45
    mesh.mesh = capsule
    var mat = StandardMaterial3D.new()
    mat.albedo_color = Color(0.12,0.45,0.9)
    mesh.material_override = mat
    mesh.position.y = 0.3
    player.add_child(mesh)

    var cs = CollisionShape3D.new()
    var shape = CapsuleShape3D.new()
    shape.height = 1.8
    shape.radius = 0.45
    cs.shape = shape
    cs.position.y = 0.3
    player.add_child(cs)

    camera = Camera3D.new()
    camera.position = Vector3(0,4.5,7.5)
    camera.rotation_degrees = Vector3(-18,0,0)
    player.add_child(camera)
    camera.current = true

func _physics_process(delta):
    if not player:
        return
    var input_vec = Input.get_vector("move_left","move_right","move_forward","move_back")
    if joystick_vector.length() > 0.1:
        input_vec = joystick_vector

    var dir = Vector3(input_vec.x,0,input_vec.y)
    player.velocity.x = dir.x * 7.0
    player.velocity.z = dir.z * 7.0
    player.velocity.y = -2.0
    player.move_and_slide()

    if dir.length() > 0.1:
        player.look_at(player.global_position + dir, Vector3.UP)

    if player.position.distance_to(Vector3(0,0,0)) < 4 and not mission_done:
        mission_done = true
        money += 100
        _update_ui()

func _make_ui():
    var layer = CanvasLayer.new()
    add_child(layer)

    ui_label = Label.new()
    ui_label.position = Vector2(25,25)
    ui_label.add_theme_font_size_override("font_size", 26)
    layer.add_child(ui_label)

    var mission = Label.new()
    mission.text = "المهمة: اذهب إلى وسط المدينة"
    mission.position = Vector2(25,70)
    mission.add_theme_font_size_override("font_size", 22)
    layer.add_child(mission)

    var help = Label.new()
    help.text = "WASD أو اسحب العصا — اجمع العملات"
    help.position = Vector2(25,115)
    help.add_theme_font_size_override("font_size", 18)
    layer.add_child(help)

    _update_ui()

func _update_ui():
    if ui_label:
        ui_label.text = "❤️ الصحة: %d    💰 المال: $%d" % [health,money]

func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x < 420 and event.position.y > 480:
            joystick_active = true
            joystick_center = event.position
        elif not event.pressed:
            joystick_active = false
            joystick_vector = Vector2.ZERO
    elif event is InputEventScreenDrag and joystick_active:
        var d = event.position - joystick_center
        joystick_vector = d.limit_length(100.0) / 100.0
