require daslib/media

struct WaveMesh
    coord: array<float2>
    uv: array<float2>
    color: uint
    count: int

struct WaterExplosion
    coord: float2
    curTime: float
    strength: float
    curStrength: float
    rad: float
    radMul: float
    fadeMul: float

struct AerialExplosion
    coord: float2
    curTime: float
    strength: float
    curStrength: float
    rad: float
    maxRad: float

struct Player
    coord: float2
    speed: float2
    angle: float
    health: float
    size: float
    weaponReload: float

struct Enemy
    coord: float2
    phase: float
    speed: float    
    health: float
    startHealth: float
    size: float2
    color: float4
    colorLights: float4
    weapon: int4
    weaponReload: float4
    weaponReloadSpeed: float4

struct EnemyBullet
    coord: float2
    target: float2
    speed: float2
    maxSpeed: float
    damage: float
    size: float
    visual: int
    hitAnim: int
    explosionType: int

struct PlayerBullet
    coord: float2
    speed: float2
    maxSpeed: float
    damage: float
    size: float
    visual: int

struct BulletVisual
    size: float
    count: int
    trace: float
    color0: float4
    color1: float4
    part: int

struct Particle
    bmap: Image
    ablendMode: int

var
    sea_wave_gradient: Image
    sky_gradient: Image
    player_ship: Image
    enemy_ship: Image
    particles: array<Particle>

    waves: array<WaveMesh>

    enemyBullets: array<EnemyBullet>
    playerBullets: array<PlayerBullet>
    waterExplosions: array<WaterExplosion>
    aerialExplosions: array<AerialExplosion>
    enemies: array<Enemy>
    player: Player

    enemyTypes: array<Enemy>
    enemyBulletTypes: array<EnemyBullet>
    playerBulletTypes: array<PlayerBullet>
    waterExplosionTypes: array<WaterExplosion>

    bulletVisuals: array<BulletVisual>

    globalSw: float
    globalSh: float

    seed = int4(762, 22, 3, 4)
    explAdd : float
    seaLevel = 0.2
    waveCount = 20
    layerThickness = seaLevel / float(waveCount)


def reset_game
    clear(enemyBullets)
    clear(playerBullets)
    clear(waterExplosions)
    clear(aerialExplosions)
    clear(enemies)

    player.coord = float2(0.5, 0.5)
    player.speed = float2(0.0, 0.0)
    player.angle = 0.0
    player.weaponReload = 0.0
    player.health = 1.0
    player.size = 0.05

def addTypedWaterExplosion(etype: int; pos: float2)
    for x in waterExplosions
        if x.strength <= 0.0
            x = waterExplosionTypes[etype]
            x.coord = pos
            return
    
    var x = waterExplosionTypes[etype]
    x.coord = pos
    waterExplosions |> push(x)

def addTypedEnemy(etype: int; phase: float; posY: float)
    for x in enemies
        if x.health <= 0.0
            x = enemyTypes[etype]
            x.phase = phase
            x.coord.y = posY
            x.speed*=rnd(0.7, 1.5)
            return
    var x = enemyTypes[etype]
    x.phase = phase
    x.coord.y = posY
    x.speed*=rnd(0.7, 1.5)
    enemies |> push(x)

def addTypedEnemyBullet(btype: int; pos: float2; targ: float2)
    if btype < 0
        return
    var target = targ + float2(rnd(-0.01, 0.01), rnd(-0.01, 0.01))
    for x in enemyBullets
        if x.damage <= 0.0
            x = enemyBulletTypes[btype]
            x.coord = pos
            x.target = target 
            x.speed = x.maxSpeed*(float2(target.x, 1.0 - target.y*seaLevel)-pos)
            return
    
    var x = enemyBulletTypes[btype]
    x.coord = pos
    x.target = target 
    x.speed = x.maxSpeed*(float2(target.x, 1.0 - target.y*seaLevel)-pos)
    enemyBullets |> push(x)

def addTypedPlayerBullet(btype: int; angle : float)
    if btype < 0
        return
    for x in playerBullets
        if x.damage <= 0.0
            x = playerBulletTypes[btype]
            x.coord = float2(player.coord.x, 1.0 - seaLevel*player.coord.y)
            x.speed = -x.maxSpeed*(float2(-sin(angle), cos(angle)))
            return
    
    var x = playerBulletTypes[btype]
    x.coord = float2(player.coord.x, 1.0 - seaLevel*player.coord.y)
    x.speed = -x.maxSpeed*(float2(-sin(angle), cos(angle)))
    playerBullets |> push(x)


def wave_simulation(pos: float2)
    var retVal = 0.0

    for x in waterExplosions
        if x.strength <= 0.0
            continue
        let explLen = length(pos - x.coord)
        if explLen >= x.rad
            continue
        var expStrength = explLen/x.rad
        expStrength = x.curStrength * (1.0 - expStrength * expStrength)
        retVal += expStrength*cos(100.0*explLen-5.0*x.curTime)

    return retVal


def smoothstep(x)
    let t = saturate(x)
    return t * t * (3.0 - 2.0 * t)


def rnd(from, to): float
    return float(from) + random_float(seed) * (float(to) - float(from))


def wave_mesh(var m: WaveMesh &; pos: float2; color_: uint; count: int; width: float; strip_thickness : float)
    m.color = color_
    m.count = count
    var p = pos
    p.y += strip_thickness
    var incr = width / float(count)
    m.coord |> push(p)
    m.uv |> push(float2(0, 0))
    for i in range(count)
        m.coord |> push(p + float2(0.0, 10.0))
        m.uv |> push(float2(0, 3))
        m.coord |> push(p + float2(incr, 0.0))
        m.uv |> push(float2(0, 0))
        p += float2(incr, 0.0)

    m.coord |> push(back(m.coord))
    m.uv |> push(back(m.uv))


[export]
def initialize
    set_window_title("WaveMeshTest")
    set_antialiasing(4)
    explAdd = 0.0

    //////////////////////////
    // TEXTURES AND MESHES
    //////////////////////////

    sea_wave_gradient <- create_image(1, 3, [{uint[] make_color(0.0, 0.0, 1.0);
                                                     make_color(0.1, 0.7, 0.9);
                                                     make_color(1.0, 1.0, 1.0)}])
    sea_wave_gradient |> set_image_smooth(true)

    sky_gradient <- create_image(2, 2, [{uint[] make_color(0.1, 0.2, 0.4);  make_color(0.25, 0.2, 0.5);
                                                make_color(0.0, 0.15, 0.0); make_color(0.0, 0.22, 0.0)}])
    sky_gradient |> set_image_smooth(true)

    player_ship <-  create_image(2, 2, [{uint[] make_color(0.8, 0.2, 0.2);  make_color(0.7, 0.2, 0.5);
                                                make_color(0.2, 0.15, 0.0); make_color(0.2, 0.22, 0.0)}])
    player_ship |> set_image_smooth(true)

    let particle_rad = 32
    particles |> resize(2)
    particles[0].bmap <- create_image(particle_rad*2, particle_rad*2)
    particles[0].bmap |> set_image_smooth(true)
    particles[0].ablendMode = 1
    particles[1].bmap <- create_image(particle_rad*2, particle_rad*2)
    particles[1].bmap |> set_image_smooth(true)
    particles[1].ablendMode = 0
    for iy in range(particle_rad*2)
        for ix in range(particle_rad*2)
            let x = float(ix - particle_rad) / float(particle_rad)
            let y = float(iy - particle_rad) / float(particle_rad)
            let angle = atan2(y, x)
            let len = length(float2(x, y))
            let k = len + (sin(angle * 10.0) + sin(angle * 18.0) + sin(angle * 34.0)) * 0.02 * len * len
            particles[0].bmap |> set_pixel(ix, iy, make_color(smoothstep(1.0 - k), 0.0))
            let bk = max(0.0, 1.0-len*len*len)*(cos(10.0*len + angle))
            particles[1].bmap |> set_pixel(ix, iy, make_color(1.0, bk))

    let enemy_rad = 32
    enemy_ship <- create_image(enemy_rad*2, enemy_rad*2)
    for iy in range(enemy_rad*2)
        for ix in range(enemy_rad*2)
            let x = float(ix - enemy_rad) / float(enemy_rad)
            let y = float(iy - enemy_rad) / float(enemy_rad)
            let angle = atan2(y, x)
            let len = length(float2(x, y))
            let k = len
            enemy_ship |> set_pixel(ix, iy, make_color(0.5-0.25*(x + y), 10.0 - 10.0*k))

    let sw = float(get_screen_width())
    let sh = float(get_screen_height())

    waves |> resize(waveCount)
    for x, i in waves, range(99999)
        wave_mesh(x, float2(0.0, sh * (1.0 - layerThickness*float(waveCount) + layerThickness*float(i))),
                     make_color(float3(1, 1, 1)), 100, sw, sh*layerThickness*3.0)

    //////////////////////////
    // GAMEPLAY MECHANICS
    //////////////////////////
    
    //// ENEMIES
    enemyTypes |> resize(4)
    // small enemy ship
    enemyTypes[0].startHealth = 0.2
    enemyTypes[0].health = enemyTypes[0].startHealth
    enemyTypes[0].size = float2(0.03, 0.015)
    enemyTypes[0].color = float4(0.5, 0.1, 0.1, 1.0)
    enemyTypes[0].colorLights = float4(0.1, 1.0, 0.1, 1.0)
    enemyTypes[0].weaponReloadSpeed = float4(0.5, 0.0, 0.0, 0.0)
    enemyTypes[0].weapon = int4(2, -1, -1, -1)
    enemyTypes[0].speed = 0.2
    // mid enemy ship
    enemyTypes[1].startHealth = 0.8
    enemyTypes[1].health = enemyTypes[1].startHealth
    enemyTypes[1].size = float2(0.06, 0.04)
    enemyTypes[1].color = float4(0.5, 0.8, 0.1, 1.0)
    enemyTypes[1].colorLights = float4(1.0, 1.0, 0.0, 1.0)
    enemyTypes[1].weaponReloadSpeed = float4(1.0, 0.2, 0.0, 0.0)
    enemyTypes[1].weapon = int4(0, 1, -1, -1)
    enemyTypes[1].speed = 0.1

    //// ENEMY WEAPONS
    enemyBulletTypes |> resize(4)
    // small enemy bullet
    enemyBulletTypes[0].maxSpeed = 0.7
    enemyBulletTypes[0].damage = 0.01
    enemyBulletTypes[0].explosionType = 0
    enemyBulletTypes[0].visual = 0
    // small depth charge
    enemyBulletTypes[1].maxSpeed = 0.3
    enemyBulletTypes[1].damage = 0.1
    enemyBulletTypes[1].explosionType = 1
    enemyBulletTypes[1].visual = 1
    // large enemy bullet
    enemyBulletTypes[2].maxSpeed = 0.4
    enemyBulletTypes[2].damage = 0.05
    enemyBulletTypes[2].explosionType = 2
    enemyBulletTypes[2].visual = 3

    //// PLAYER WEAPONS
    playerBulletTypes |> resize(4)
    // small player bullet
    playerBulletTypes[0].maxSpeed = 0.7
    playerBulletTypes[0].damage = 0.1
    playerBulletTypes[0].visual = 2

    //// WATER EXPLOSIONS
    waterExplosionTypes |> resize(4)
    // empty explosion
    waterExplosionTypes[0].strength = 0.0
    waterExplosionTypes[0].curTime = 0.0
    waterExplosionTypes[0].fadeMul = 1000.0
    waterExplosionTypes[0].radMul = 0.0
    // depth charge explosion
    waterExplosionTypes[1].strength = 0.05
    waterExplosionTypes[1].curTime = 0.0
    waterExplosionTypes[1].fadeMul = 0.3
    waterExplosionTypes[1].radMul = 0.07
    // large bullet explosion
    waterExplosionTypes[2].strength = 0.03
    waterExplosionTypes[2].curTime = 0.0
    waterExplosionTypes[2].fadeMul = 0.5
    waterExplosionTypes[2].radMul = 0.05

    //////////////////////////
    // VISUAL EFFECTS
    //////////////////////////
    bulletVisuals |> resize(4)
    // small enemy bullet
    bulletVisuals[0].size = 10.0
    bulletVisuals[0].count = 3
    bulletVisuals[0].trace = 0.1
    bulletVisuals[0].part = 0
    bulletVisuals[0].color0 = float4(1.0, 0.0, 0.0, 1.0)
    bulletVisuals[0].color1 = float4(1.0, 0.5, 0.0, 1.0)
    // small depth charge
    bulletVisuals[1].size = 22.0
    bulletVisuals[1].count = 10
    bulletVisuals[1].trace = 0.2
    bulletVisuals[1].part = 1
    bulletVisuals[1].color0 = float4(1.0, 1.0, 0.0, 1.0)
    bulletVisuals[1].color1 = float4(4.0, 0.0, 0.0, 0.7)
    // small player bullet
    bulletVisuals[2].size = 15.0
    bulletVisuals[2].count = 4
    bulletVisuals[2].trace = 0.07
    bulletVisuals[2].part = 0
    bulletVisuals[2].color0 = float4(0.0, 1.0, 0.0, 1.0)
    bulletVisuals[2].color1 = float4(0.0, 1.0, 2.0, 1.0)
    // large enemy bullet
    bulletVisuals[3].size = 10.0
    bulletVisuals[3].count = 6
    bulletVisuals[3].trace = 0.2
    bulletVisuals[3].part = 0
    bulletVisuals[3].color0 = float4(1.0, 0.0, 1.0, 1.0)
    bulletVisuals[3].color1 = float4(0.0, 0.0, 4.0, 1.0)


    reset_game()

def gameSimulation(dt: float)

    // simulate enemies
    for x in enemies
        if (x.health<=0.0)
            continue
        x.phase += dt*x.speed
        x.coord.x = 0.5+0.4*sin(x.phase)
        x.weaponReload += dt * x.weaponReloadSpeed
        if (x.weaponReload.x > 1.0) // main gun, pointing at player
            addTypedEnemyBullet(x.weapon.x, x.coord, player.coord)
            x.weaponReload.x = 0.0
        if (x.weaponReload.y > 1.0) // depth charge, fall
            addTypedEnemyBullet(x.weapon.y, x.coord, float2(x.coord.x, player.coord.y))
            x.weaponReload.y = 0.0

    // simulate enemy bullets
    for x in enemyBullets
        if x.damage <= 0.0
            continue
        x.coord += x.speed * dt
        if (x.coord.y > 1.0 - seaLevel*x.target.y)
            addTypedWaterExplosion(x.explosionType, x.target)
            // calculate collision with player
            if (length(x.target - player.coord)<= player.size)
                player.health -= x.damage
            x.damage = -1.0

    // simulate player bullets
    for x in playerBullets
        if x.damage <= 0.0
            continue
        x.coord += x.speed * dt
        if (x.coord.x > 1.0 || x.coord.y > 1.0 || x.coord.x < 0.0 || x.coord.y < 0.0)
            x.damage = -1.0
            continue
        // calculate collision with enemy ships
        for eShip in enemies
            if (eShip.health<=0.0)
                continue
            if (abs(eShip.coord.x - x.coord.x) - x.size < 0.5*eShip.size.x && abs(eShip.coord.y - x.coord.y) - x.size < 0.5*eShip.size.y)
                eShip.health -= x.damage
                x.damage = -1.0
            

    // simulate waterExplosions
    for x in waterExplosions
        if x.strength <= 0.0
            continue
        x.curTime += dt
        x.curStrength = min(x.curTime*10.0, 1.0)*(x.strength * exp(-x.fadeMul*x.curTime) - 0.01)
        x.rad = 0.005 + x.curTime * x.radMul
        x.coord.y -= 0.01*dt

        if (x.curStrength < 0.0)
            x.strength = -1.0

    // simulate player
    player.speed *= exp(-4.0*dt)

    if get_key(VK_LEFT)
        player.speed.x = -0.15 
    if get_key(VK_RIGHT)
        player.speed.x = 0.15
    if get_key(VK_UP)
        player.speed.y = 0.15
    if get_key(VK_DOWN)
        player.speed.y = -0.15

    player.coord.x = clamp(player.coord.x + player.speed.x * dt, 0.000001, 0.999999)
    player.coord.y = clamp(player.coord.y + player.speed.y * dt, 0.000001, 0.999999)

    var p1 = wave_simulation(float2(player.coord.x - player.size*0.5, player.coord.y))
    var p2 = wave_simulation(float2(player.coord.x + player.size*0.5, player.coord.y))
    player.angle = atan((p1 - p2) / player.size)

    player.weaponReload += 5.0*dt
    if (get_key(VK_SPACE) && player.weaponReload >= 1.0)
        addTypedPlayerBullet(0, player.angle)
        player.weaponReload = 0.0


    player.health  = 1.0

    if (player.health <= 0.0)
        reset_game()

[export]
def act(dt: float)
    explAdd += dt
    if (explAdd > 2.9)
        addTypedEnemy(int(rnd(0.1, 1.9)), rnd(0.0, 3.1415), rnd(0.1, 0.45))
        explAdd = 0.0;
    gameSimulation(dt)
    
    if get_key(VK_ESCAPE)
        schedule_quit_game()

def render_bullet_visual(vtype: int; bpos: float2; speed: float2)
    let sw = globalSw
    let sh = globalSh
    let num = bulletVisuals[vtype].count + 1
    if (particles[bulletVisuals[vtype].part].ablendMode == 0)
        enable_alpha_blend()
    else
        enable_premultiplied_alpha_blend()
    for i in range(num)
        let k = float(i) / float(num)

        let pos = (bpos - k*speed*bulletVisuals[vtype].trace) * float2(sw, sh)
        let sz = bulletVisuals[vtype].size * (1.0 - k)

        var st = 10.0*get_time_after_start() + 10.0*k
        let vecx = float2(sz * 0.5 * cos(st), sz * 0.5 * sin(st))
        let vecy = float2(-sz * 0.5 * sin(st), sz * 0.5 * cos(st))
        particles[bulletVisuals[vtype].part].bmap |> draw_quad(pos - vecx - vecy,
                                                               pos + vecx - vecy,
                                                               pos + vecx + vecy,
                                                               pos - vecx + vecy,
                                                               make_color(bulletVisuals[vtype].color0 * (1.0 - k) + bulletVisuals[vtype].color1 * k))
    disable_alpha_blend()


def render_enemy_visual(enemy: Enemy)
    let sw = globalSw
    let sh = globalSh
    enable_alpha_blend()

    var pos = enemy.coord * float2(sw, sh)
    var sz = enemy.size * float2(sw, sh)

    var st = 0.0//10.0*get_time_after_start() + 10.0*k
    var vecx = float2(sz.x * 0.5 * cos(st), sz.x * 0.5 * sin(st))
    var vecy = float2(-sz.y * 0.5 * sin(st), sz.y * 0.5 * cos(st))
    enemy_ship |> draw_quad(pos - vecx - vecy,
                            pos + vecx - vecy,
                            pos + vecx + vecy,
                            pos - vecx + vecy,
                            make_color(enemy.color))
    
    
    enable_premultiplied_alpha_blend()
    let lights_count = 3
    let colorMul = enemy.health / enemy.startHealth
    var sz1 = max(sz.x, sz.y)*0.15

    for i in range(-lights_count, lights_count+1)
        let k = float(i) / float(lights_count)

        let posL = pos + float2(sz.x*0.5, 0.0)*k

        let normalWork = colorMul*0.25*(3.0 + sin(10.0*get_time_after_start() + 3.0*k + enemy.phase))
   
        vecx = float2(sz1 * 0.5 * cos(st), sz1 * 0.5 * sin(st))
        vecy = float2(-sz1 * 0.5 * sin(st), sz1 * 0.5 * cos(st))
        particles[0].bmap |> draw_quad( posL - vecx - vecy,
                                        posL + vecx - vecy,
                                        posL + vecx + vecy,
                                        posL - vecx + vecy,
                                        make_color(enemy.colorLights*normalWork))

    disable_alpha_blend()


[export]
def draw
    sky_gradient |> draw_image(0.0, 0.0, make_color(1.0),
        float2(get_screen_width(), get_screen_height()))

    let t = get_time_after_start()

    globalSw = float(get_screen_width())
    globalSh = float(get_screen_height())

    let sw = globalSw
    let sh = globalSh

    // render water waves
    for x, i in waves, range(1000)
        let tmpH = 1.0 - float(i) / float(waveCount)
        for j in range(x.count)
            let tmpW = float(j) / float(x.count)
            var delta = -0.5*1.25*(4.0 + sin(t + 17.0*tmpH) + sin(3.0*t + 15.0*tmpW) + sin(2.0*t + 10.5*(tmpW + tmpH)) + sin(2.0*t + 20.0*(tmpW - tmpH)))
            delta -= wave_simulation(float2(tmpW, tmpH))*sh
            x.coord[2*j+1].y = x.coord[2*j].y + delta - sh*layerThickness*3.0;
            x.uv[2*j+1].y = 1.0 + min(0.1*abs(delta), 2.0)

        sea_wave_gradient |> draw_triangle_strip(x.coord, x.uv, x.color)

        // render player's ship
        if player.coord.y >= tmpH - 1.0 / float(waveCount) && player.coord.y < tmpH
            let sz = player.size * 0.5
            let st = player.angle
            let vecx = float2(sz * cos(st) * sw, sz * sin(st) * sh)
            let vecy = float2(-sz * sin(st) * sw, sz * cos(st) * sh)
            let pos = float2(player.coord.x * sw, (1.0 - (player.coord.y - 0.0*player.size) * seaLevel) * sh)
            player_ship |> draw_quad(pos - vecx - vecy,
                                    pos + vecx - vecy,
                                    pos + vecx + vecy,
                                    pos - vecx + vecy, make_color(1.0, 1.0, 1.0))
            line(pos.x, pos.y, pos.x + sh * sin(st), pos.y - sh * cos(st), make_color(1.0, 0.0, 0.0))
    
    // render enemy bullets
    for x in enemyBullets
        if x.damage <= 0.0
            continue
        render_bullet_visual(x.visual, x.coord, x.speed)

    // render player bullets
    for x in playerBullets
        if x.damage <= 0.0
            continue
        render_bullet_visual(x.visual, x.coord, x.speed)

    // render enemies
    for x in enemies
        if (x.health<=0.0)
            continue
        render_enemy_visual(x)


    // render HUD
    var healthInt = int(player.health * 100.0)
    var healthInfo = "Health {healthInt}"
    text_out(10.0, 40.0, healthInfo, make_color(1.0, 0.0, 0.0))