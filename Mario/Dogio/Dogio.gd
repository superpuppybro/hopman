
extends KinematicBody2D

onready var sprite = get_node( "Sprite" )
onready var sfx = get_node( "SFX" )
onready var col = get_node("Collider")

onready var animator = get_node("Animator")
#This is a simple collision demo showing how
#the kinematic cotroller works.
#move() will allow to move the node, and will
#always move it to a non-colliding spot, 
#as long as it starts from a non-colliding spot too.


#pixels / second
const GRAVITY = 500.0

#Angle in degrees towards either side that the player can 
#consider "floor".
const FLOOR_ANGLE_TOLERANCE = 40
const WALK_FORCE = 600
const WALK_MIN_SPEED=10
const WALK_MAX_SPEED = 200
const STOP_FORCE = 1300
const JUMP_SPEED = 250
const JUMP_MAX_AIRBORNE_TIME=0.2

const SLIDE_STOP_VELOCITY=1.0 #one pixel per second
const SLIDE_STOP_MIN_TRAVEL=1.0 #one pixel

export(Texture) var small_texture = null
export(Texture) var big_texture = null

var big_shape = {'pos': Vector2(0,3), "shape": RectangleShape2D.new() }
var small_shape = {'pos': Vector2(0,8), "shape": RectangleShape2D.new() }

var velocity = Vector2()
var on_air_time=100
var jumping=false

var prev_jump_pressed=false

var facing = 1 setget _set_facing

var dead = false

var ducking = false setget _set_ducking

var anim = "idle" setget _set_anim

func die():
	set_fixed_process( false )
	sfx.play( "death" )
	self.dead = true

func get_coin( coin ):
	sfx.play( "coin" )
	coin.queue_free()

func _fixed_process(delta):
	var new_facing = self.facing
	var new_anim = "idle"
	#create forces
	var force = Vector2(0,GRAVITY)
	
	var walk_left = Input.is_action_pressed("LEFT")
	var walk_right = Input.is_action_pressed("RIGHT")
	var down = Input.is_action_pressed("DOWN")
	var up = Input.is_action_pressed("UP")
	var jump = Input.is_action_pressed("JUMP")

	var stop=true
	
	if (walk_left):
		if (velocity.x<=WALK_MIN_SPEED and velocity.x > -WALK_MAX_SPEED):
			force.x-=WALK_FORCE			
			stop=false
		new_anim = "run"
		
	elif (walk_right):
		if (velocity.x>=-WALK_MIN_SPEED and velocity.x < WALK_MAX_SPEED):
			force.x+=WALK_FORCE
			stop=false
		new_anim = "run"
	
	if (stop):
		var vsign = sign(velocity.x)
		var vlen = abs(velocity.x)
		
		vlen -= STOP_FORCE * delta
		if (vlen<0):
			vlen=0
			
		velocity.x=vlen*vsign
		

		
	
		
	#integrate forces to velocity
	velocity += force * delta
	
	#integrate velocity into motion and move
	var motion = velocity * delta

	#move and consume motion
	motion = move(motion)


	var floor_velocity=Vector2()
	
	self.ducking = down
	
	
	if (is_colliding()):
		# you can check which tile was collision against with this
		# print(get_collider_metadata())
		
		#ran against something, is it the floor? get normal
		var n = get_collision_normal()
		
		var c = get_collider()
		
		# Detect bricks hitting our head
		if c.is_in_group("bricks"):
			if ( rad2deg(acos(n.dot( Vector2(0,1)))) < FLOOR_ANGLE_TOLERANCE ):
				c.break_bricks()
		
		if ( rad2deg(acos(n.dot( Vector2(0,-1)))) < FLOOR_ANGLE_TOLERANCE ):
			#if angle to the "up" vectors is < angle tolerance
			#char is on floor
			on_air_time=0
			floor_velocity=get_collider_velocity()
			
			
			
			if walk_right or walk_left:
				new_facing = sign( velocity.x )

		if (on_air_time==0 and force.x==0 and get_travel().length() < SLIDE_STOP_MIN_TRAVEL and abs(velocity.x) < SLIDE_STOP_VELOCITY and get_collider_velocity()==Vector2()):
			#Since this formula will always slide the character around, 
			#a special case must be considered to to stop it from moving 
			#if standing on an inclined floor. Conditions are:
			# 1) Standing on floor (on_air_time==0)
			# 2) Did not move more than one pixel (get_travel().length() < SLIDE_STOP_MIN_TRAVEL)
			# 3) Not moving horizontally (abs(velocity.x) < SLIDE_STOP_VELOCITY)
			# 4) Collider is not moving
						
			revert_motion()
			velocity.y=0.0

		else:
			#For every other case of motion,our motion was interrupted.
			#Try to complete the motion by "sliding"
			#by the normal				
			
			motion = n.slide(motion)
			velocity = n.slide(velocity)		
			#then move again
			move(motion)

	if (floor_velocity!=Vector2()):
		#if floor moves, move with floor
		move(floor_velocity*delta)

	if (jumping and velocity.y>0):
		#if falling, no longer jumping
		jumping=false
		
	if (on_air_time<JUMP_MAX_AIRBORNE_TIME and jump and not prev_jump_pressed and not jumping):	
		# Jump must also be allowed to happen if the
		# character left the floor a little bit ago.
		# Makes controls more snappy.
		velocity.y=-JUMP_SPEED	
		jumping=true
		sfx.play( "jump" )
		
	on_air_time+=delta
	prev_jump_pressed=jump	
	
	if on_air_time > JUMP_MAX_AIRBORNE_TIME:
		new_anim = "jump"
	if ducking:
		new_anim = "crouch"
	if new_facing != self.facing:
		self.facing = new_facing
	
	if new_anim != self.anim:
		self.anim = new_anim
	
	var y = get_pos().y
	if y > 240:
		die()
	
func _ready():
	#Initalization here
	small_shape.shape.set_extents( Vector2(5,7) )
#	small_shape.pos = Vector2(0,5) 
	big_shape.shape.set_extents( Vector2(5,13) )
#	small_shape.pos = Vector2(0,3)

	get_parent().player = self
	set_fixed_process(true)
	

func _set_facing( what ):
	facing = what
	sprite.set_scale( Vector2( facing, 1 ) )


func _set_ducking( what ):
	if ducking != what:
		if what:
#			col.set_pos( small_shape.pos )
			set_shape_transform( 0, Matrix32( 0.0, small_shape.pos ) )
			set_shape( 0, small_shape.shape )


			
		else:
#			col.set_pos( big_shape.pos )
			set_shape_transform( 0, Matrix32( 0.0, big_shape.pos ) )
			set_shape( 0, big_shape.shape )

			

	
	ducking = what




func _set_anim( what ):
	anim = what
	animator.play( anim )
