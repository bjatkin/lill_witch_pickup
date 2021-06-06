pico-8 cartridge // http://www.pico-8.com
version 32
__lua__
-- main gameplay
black,dark_blue,dark_purple,dark_green,brown,dark_gray,light_gray,white,red,orange,yellow,green,blue,indigo,pink,peach=0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
_debug = ""

function _init()
    kiki = {
        dy= 0,
        dx= 0,
        x= 50,
        y= 50, 
        mirror= false,
        drop_cd= 0,
        dash_cd= 0,
        drop_done=true,
        carry_weight=0,
        d_frames=0,
        i_frames=0,
    }

    cam = {
        x=0,
        y=0,
        max_dx=7,
        offset_x=64,
        offset_y=0,
    }

    delivered = 0
    orders = {}
    planes = {}
    birds = {new_bird(50, false), new_bird(60, true)}

    frames = 0
    day_length = 60 * 60
    air_resistance, acc, gravity = 0.9, 0.3, 0.1
    max_carry_weight = 5

    init_main_menu()
    update_fn = update_main_menu
    draw_fn = draw_main_menu
end

function new_order(pickup, dropoff)
    return {
        pickup=pickup,
        dropoff=dropoff,
        got=false,
    }
end

function new_plane(pos, mirror)
    return {
        x=pos,
        y=rnd(90),
        mirror=mirror
    }
end

function new_bird(pos, mirror)
    return {
        x=pos,
        y=rnd(90)+10,
        mirror=mirror,
    }
end

function _update60()
    update_fn()
end

function _draw()
    draw_fn()
end

-->8
-- gameplay
function update_gameplay()
    frames += 1
    local move = false
    if btn(⬅️) then
        kiki["dx"] -= acc 
        kiki["mirror"] = false
        move = true
    end
    if btn(➡️) then
        kiki["dx"] += acc 
        kiki["mirror"] = true
        move = true
    end
    if btn(⬇️) then
        kiki["dy"] += acc/2
    end
    if btn(⬆️) then
        kiki["dy"] -= acc/2
    end

    -- drop
    kiki["drop_cd"] -= 1
    if btnp(🅾️) and kiki["drop_cd"] <= 0 and kiki["drop_done"] then
        kiki["dy"] = 6
        kiki["drop_cd"] = 30
        kiki["drop_done"] = false
    end
    if btn(🅾️) then
        kiki["dx"] *= 0.2
    end
    if not btn(🅾️) then
        kiki["drop_done"] = true
    end

    -- dash
    kiki["dash_cd"] -= 1
    if btnp(❎) and kiki["dash_cd"] <= 0 then
        if kiki["mirror"] then
            kiki["dx"] = 10
        else
            kiki["dx"] = -10
        end
        kiki["dash_cd"] = 60
        kiki["i_frames"] = 30
    end

    kiki["dx"] *= air_resistance
    kiki["dy"] *= air_resistance
    if kiki["y"] < 0 then
        kiki["dy"] += gravity
    end

    kiki["d_frames"] -= 1
    kiki["i_frames"] -= 1

    -- set kiki position
    kiki["x"] += kiki["dx"]
    kiki["y"] += kiki["dy"]
    if kiki["y"] > 90 and kiki["dy"] >= 0 then
        kiki["dy"] *= 0.2
        kiki["dx"] *= 0.2
    end
    if kiki["d_frames"] > 0 then
        kiki["dy"] *= 0.2
        kiki["dx"] *= 0.2
    end

    if kiki["x"] < 0 then
        kiki["x"] = 0
    end
    if kiki["x"] > 2040 then
        kiki["x"] = 2040
    end


    -- set camera position
    move_camera(kiki["x"], kiki["y"], not move, kiki["mirror"])

    -- add in new pickup and drop off's randomly
    -- TODO: don't spawn too close to the player
    -- TODO: make sure to spawn the drop off spot a little ways from the player
    -- TODO: don't spawn pickup and drop off spots too close to each other
    if flr(rnd(60 * 3)) == 1 then
        add(orders, new_order(rnd(2048), rnd(2048)))
    end

    -- add in new planes
    if flr(rnd(60 * 3)) == 1 then
        spawn_plane(kiki["x"], not kiki["mirror"])
    end

    -- add in new birds
    if flr(rnd(60 * 3)) == 1 then
        spawn_bird(kiki["x"], not kiki["mirror"])
    end
    
    -- check pickup/ dropoff
    local pickup, dropoff = check_pickup(), check_dropoff()
    if pickup > 0 and kiki["carry_weight"] < max_carry_weight then
        orders[pickup]["got"] = true
        kiki["carry_weight"] += 1
    end
    if dropoff > 0 and kiki["carry_weight"] > 0 then
        deli(orders, dropoff)
        kiki["carry_weight"] -= 1
        delivered += 1
    end

    if frames > day_length + 240 then
        frames = 0
        camera(0, 0)
        fadepal(0)
        update_fn = update_score_board
        draw_fn = draw_score_board
    end

    -- update planes
    keep_planes = {}
    for _, plane in ipairs(planes) do
        if plane["mirror"] then
            plane["x"] += 2
        else
            plane["x"] -= 2
        end
        if plane["x"] > -100 and plane["x"] < 3000 then
            add(keep_planes, plane)
        end

        -- check plane collision
        if kiki["x"]+4 > plane["x"] and kiki["x"]+4 < plane["x"]+16 and kiki["y"]+4 > plane["y"] and kiki["y"]+4 < plane["y"]+8 then
            if kiki["d_frames"] <= 0 and kiki["i_frames"] <= 0 then
                kiki["d_frames"] = 45 
            end
        end
    end

    planes = keep_planes

    -- update birds
    keep_birds = {}
    for _, bird in ipairs(birds) do
        if bird["mirror"] then
            bird["x"] += 1
        else
            bird["x"] -= 1
        end
        if flr(rnd(3)) == 1 then
            if bird["y"] + 2 < kiki["y"] + 4 then
                bird["y"] += 0.5
            end
            if bird["y"] + 6 > kiki["y"] + 4 then
                bird["y"] -= 0.5
            end
            if bird["x"] > -100 and bird["x"] < 3000 then
                add(keep_birds, bird)
            end
        end

        -- check bird collision
        if kiki["x"]+4 > bird["x"] and kiki["x"]+4 < bird["x"]+8 and kiki["y"]+4 > bird["y"] and kiki["y"]+4 < bird["y"]+8 then
            if kiki["d_frames"] <= 0 and kiki["i_frames"] <= 0 then
                kiki["d_frames"] = 45 
            end
        end
    end
end

function spawn_plane(x, mirror)
    if mirror then
        add(planes, new_plane(x-160, mirror))
    else
        add(planes, new_plane(x+160, mirror))
    end
end

function spawn_bird(x, mirror)
    if mirror then
        add(birds, new_bird(x-160, mirror))
    else
        add(birds, new_bird(x+160, mirror))
    end
end

function check_pickup()
    local dist = 10
    for i, order in ipairs(orders) do
        if not order["got"] then
            if kiki["y"] > 90 and kiki["x"] + 4 > order["pickup"] - dist and kiki["x"] + 4 < order["pickup"] + 8 + dist then
                return i
            end
        end
    end
    return -1
end

function check_dropoff()
    local dist = 10
    for i, order in ipairs(orders) do
        if order["got"] then
            if kiki["y"] > 90 and kiki["x"] + 4 > order["dropoff"] - dist and kiki["x"] + 4 < order["dropoff"] + 8 + dist then
                return i
            end
        end
    end
    return -1
end

function draw_gameplay()
    if frames < day_length then
        cls(blue)
    end
    if frames >= day_length then
        cls(dark_blue)
    end
    if frames > day_length + 100 then
        cls(black)
    end

    -- draw the ui
    camera(0, 0)
    draw_dash_ui()
    draw_weight_ui()
    draw_score()

    -- draw ocean
    rectfill(0, 123, 128, 128, dark_blue)

    print(_debug, 5, 15, red)
    _debug = ""

    if cam["x"] < 0 then
        cam["x"] = 0
    end
    if cam["x"] > 2048-128 then
        cam["x"] = 2048-128
    end

    camera(cam["x"], cam["y"])
    hills_offset = cam["x"]*0.95
    city_offset = cam["x"]*0.8
    do_day_cycle(frames)

    -- draw the map

    -- rolling hills
    map(0, 24, 0+hills_offset, 36, 128, 8)
    map(0, 24, 1024+hills_offset, 36, 128, 8)

    -- city bg
    map(0, 16, 0+city_offset, 50, 128, 8)
    map(0, 16, 1024+city_offset, 50, 128, 8)

    map(0, 0, 0, 64, 128, 8)
    map(0, 8, 1024, 64, 128, 8)

    -- draw pickup/ dropoff
    for _, order in ipairs(orders) do
        if order["got"] then
            spr(22, order["dropoff"]-4, 97, 2, 2)
            spr(18+(frames/20)%4, order["dropoff"], 100)
        else
            spr(22, order["pickup"]-4, 97, 2, 2)
            spr(16+(frames/20)%2, order["pickup"], 100)
        end
    end

    -- draw kiki
    palt(black, false)
    palt(blue, true)
    if kiki["d_frames"] > 0 then
        if frames%4 == 0 then
            spr(1, kiki["x"], kiki["y"]+sin(frames/60)*1.5, 1, 1, not kiki["mirror"], false)
        end
    else
        spr(1, kiki["x"], kiki["y"]+sin(frames/60)*1.5, 1, 1, not kiki["mirror"], false)
    end

    frame_offset = {0, 1, 2, 1}
    -- draw planes
    for _, plane in ipairs(planes) do
        spr(9+frame_offset[1+flr(frames/30)%4]*2, plane["x"], plane["y"], 2, 1, plane["mirror"], false)
    end

    -- draw birds
    for _, bird in ipairs(birds) do
        spr(24+frame_offset[1+flr(frames/10)%4], bird["x"], bird["y"], 1, 1, bird["mirror"], false)
    end
end

function move_camera(x, y, center, face_right)
    -- choose the x goal point for the camera
    if center then
        cam["offset_x"] += (cam["offset_x"] - 64) * -0.05
        goal_x = x - cam["offset_x"]
    end
    if not center and face_right then
        cam["offset_x"] += (cam["offset_x"] - 10) * -0.1
        goal_x = x - cam["offset_x"]
    end
    if not center and not face_right then
        cam["offset_x"] += (cam["offset_x"] - 110) * -0.1
        goal_x = x - cam["offset_x"]
    end

    -- move towards the x goal point
    local cam_dx = (cam["x"] - goal_x) * -0.3
    if cam_dx > cam["max_dx"] then
        cam_dx = cam["max_dx"]
    end
    if cam_dx < -cam["max_dx"] then
        cam_dx = -cam["max_dx"]
    end

    -- set camera x
    cam["x"] += cam_dx

    -- set camera y
    cam["y"] += (cam["y"] - (y - 20)) * -0.05
    if cam["y"] > 0 then
        cam["y"] = 0
    end
end

-->8
-- score board
function update_score_board()
    if btnp(❎) or btnp(🅾️) then
        init_main_menu()
        update_fn = update_main_menu
        draw_fn = draw_main_menu
    end
end

function draw_score_board()
    cls(blue)
    print("final score: " .. delivered, 35, 20, red)
    print("press ❎/🅾️ to return", 24, 80, red)
    print("to the menu", 38, 90, red)
end

-->8
-- main menu
function init_main_menu()
    music(0)
    mm_frames = 0
    plane_count_down = 0
    plane_height = 0
    plane_dir = 0
    plane_front = false
    plane_red = false
end

function update_main_menu()
    if btnp(❎) or btnp(🅾️) then
        delivered = 0
        draw_fn = draw_gameplay
        update_fn = update_gameplay

        music(-1, 300)
        sfx(-1, 3)
    end
end

function draw_main_menu()
    mm_frames += 1
    plane_count_down -= 1

    cls(blue)
    a, b, d, e = flr(sin(mm_frames/230)), flr(sin(mm_frames/350+0.25)), flr(sin(mm_frames/195)+0.5), flr(sin(mm_frames/440)+0.75)

    -- top clouds
    circfill(0+b, 13+a, 12, white)
    circfill(8+a, -1+b, 13, white)
    circfill(80+d, -9+b, 12, white)
    circfill(58+d, -5+a, 14, white)
    circfill(118+e, -1+e, 12, white)
    circfill(129+a, 6+d, 14, white)
    circfill(132+b, 30+a, 8, white)

    circfill(-1+b, -4+d, 11, light_gray)
    circfill(63+a, -9+e, 11, light_gray)
    circfill(126+a, -6+a, 10, light_gray)
    circfill(131+d, 12+a, 6, light_gray)

    -- bottom clouds
    rectfill(0+a, 100+b, 128, 128, white)
    circfill(10+a, 95+e, 20, white)
    circfill(32+a, 105+a, 14, white)
    circfill(55+d, 98+d, 14, white)
    circfill(78+d, 102+e, 12, white)
    circfill(100+e, 100+b, 18, white)
    circfill(128+b, 88+a, 16, white)

    circfill(0+e, 116+d, 14, light_gray)
    circfill(15+d, 130+b, 14, light_gray)
    circfill(32+e, 126+a, 12, light_gray)
    circfill(50+a, 135+e, 13, light_gray)
    circfill(90+a, 134+d, 12, light_gray)
    circfill(110+b, 126+a, 14, light_gray)
    circfill(128+b, 109+e, 15, light_gray)
    circfill(128+d, 128+a, 12, light_gray)

    if not plane_front and plane_count_down > 0 then
        draw_flyby_plane(plane_height, plane_dir)
    end

    spr(32, 33, 20, 6, 4) 
    spr(54, 82, 28, 2, 3) 
    print("delivery service", 33, 53, white)
    print("press ❎/🅾️", 41, 106, blue)
    print("to start", 47, 114, blue)

    draw_kiki_fly_in()

    if plane_count_down < 0 and flr(rnd(180)) == 1 then
        plane_height = rnd(40) + 15
        plane_dir = (flr(rnd(2))*2)-1
        plane_count_down = 200
        plane_x = 150
        if plane_dir == 1 then
            plane_x = -20
        end
        if flr(rnd(2)) == 1 then
            plane_front = not plane_front
        end
        if flr(rnd(2)) == 1 then
            plane_red = not plane_red
        end
    end
    if plane_front and plane_count_down > 0 then
        draw_flyby_plane(plane_height, plane_dir)
    end
end

function draw_kiki_fly_in()
    palt(black, false)
    palt(blue, true)
    spr(0+(mm_frames/60)%2, 60+flr(sin(mm_frames/800)*16), 72+flr(sin(mm_frames/320)*8))
end

function draw_flyby_plane(height, dir)
    if plane_red then
        pal(11, 8)
        pal(3, 2)
    else
        pal()
    end
    plane_x = plane_x + dir
    palt(blue, true)
    plane_frames = {9, 11, 9, 13}
    if dir > 0 then
        spr(plane_frames[1+flr(mm_frames/25)%4], plane_x, height, 2, 1, true, false)
    else
        spr(plane_frames[1+flr(mm_frames/25)%4], plane_x, height, 2, 1, false, false)
    end
    if plane_x > -50 and plane_x < 200 then
        sfx(4, 3)
    else
        sfx(-1, 3)
    end
end

-->8
-- ui
function draw_dash_ui()
    if kiki["dash_cd"] <= 0 then
        spr(28, 5, 5)
    else
        spr(27, 5, 5)
    end
end

function draw_weight_ui()
    for i=1,max_carry_weight,1 do
        if i <= kiki["carry_weight"] then
            spr(30, 95+i*5, 5)
        else
            spr(29, 95+i*5, 5)
        end
    end
end

function draw_score()
    print(delivered, 60, 5, red)
end

function do_day_cycle(daytime)
    fadepal(0)
    if daytime < 20 then
        fadepal(1-(daytime/20))
    end
    if daytime > day_length then
        fadepal((daytime-day_length)/240)
    end
end

function fadepal(_perc)
 -- this function sets the
 -- color palette so everything
 -- you draw afterwards will
 -- appear darker
 -- it accepts a number from
 -- 0 means normal
 -- 1 is completely black
 -- this function has been
 -- adapted from the jelpi.p8
 -- demo
 
 -- first we take our argument
 -- and turn it into a 
 -- percentage number (0-100)
 -- also making sure its not
 -- out of bounds  
 local p=flr(mid(0,_perc,1)*100)
 
 -- these are helper variables
 local kmax,col,dpal,j,k
 
 -- this is a table to do the
 -- palette shifiting. it tells
 -- what number changes into
 -- what when it gets darker
 -- so number 
 -- 15 becomes 14
 -- 14 becomes 13
 -- 13 becomes 1
 -- 12 becomes 3
 -- etc...
 dpal={0,1,1, 2,1,13,6,
          4,4,9,3, 13,1,13,14}
 
 -- now we go trough all colors
 for j=1,15 do
  --grab the current color
  col = j
  
  --now calculate how many
  --times we want to fade the
  --color.
  --this is a messy formula
  --and not exact science.
  --but basically when kmax
  --reaches 5 every color gets 
  --turns black.
  kmax=(p+(j*1.46))/22
  
  --now we send the color 
  --through our table kmax
  --times to derive the final
  --color
  for k=1,kmax do
   col=dpal[col]
  end
  
  --finally, we change the
  --palette
  pal(j,col)
 end
end

__gfx__
ccc88cccccc880ccccccccccccccccccccccccccccc88ccccc8888ccccc88ccccc8888cccccccccccccccccbcccbbbbbbccccccbccccccccccccccc3cccccccc
ccc800ccccc80fccc22c88ccaa1212ccccccccccccc800cccc8008cccc008ccccc8008cccccbbbbbbccccc33cccbbbbbbcccccbbcccbbbbbbccccc33cccccccc
cccc0fccccc022ccc22288ccaa2222ffcccccccccccc0fcccccffcccccf0ccccccc00cccc7c1b11b111cc333c7c13113111cc333c7c13113111cc331cccccccc
ccc022cccc0222c0a222880caa222220aa21222cccc022ccccc22ccccc220ccccc0000ccc733133133333331c633b33b33333331c633133133333331cccccccc
cc2222c0aa222220a222200fcc222220aaf222ffcc22220cccc20cccc02222ccccc22cccc633133133331111c733133133331111c733133133331111cccccccc
aa222220aa2222ffaa22c00cccc8822caa22122cca22220ccca20accc02222accc9a9accc711b11b1111111cc7113113111111ccc711b11b1111111ccccccccc
aa1212ffaa1c1cccccccccccccc880ccccc880ccca121ffccca11acccff121accca9a9cccccbbbbbbcccccccccc3b33b3ccccccccccbbbbbbccccccccccccccc
aaccccccccccccccccccccccccc880cccccccccccaacccccccaaaacccccccaaccc9a9accccccccccccccccccccccccccccccccccccc333333ccccccccccccccc
cccc442cccccccccccc11cccccc11cccccc11cccccc11ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cc4442cccc22222cc11cc11ccc1cc1ccccc11ccccc1cc1cccccccc7777cccccccccccccccccccccccccccccc67cc67cc8ecc8ecccccccccccccccccccccccccc
c242222c22444422c1c11c1ccc1111ccccc11ccccc1111cccccc77777777ccccc1ccc1ccccccccccccccccccc67cc67cc8ecc8ecccc66cccccc88ccccccccccc
24222242242222421c111cc1c1c11c1cccc11cccc1c11c1cccc7777777777ccccc1c1ccc1ccccc1cc11c11cccc67cc67cc8ecc8ecc6cc6cccc8ee8cccccccccc
24442422244424221c1111c1c1c11c1cccc11cccc1c11c1cccc7777777777ccccc1c1cccc11c11cc1cc1cc1ccc67cc67cc8ecc8ecc6cc6cccc8ee8cccccccccc
2444224224442242c1cccc1ccc1cc1ccccc11ccccc1cc1cccc777777777777ccccc1ccccccc1ccccccccccccc66cc66cc88cc88cccc66cccccc88ccccccccccc
2244242c2244242cc11cc11ccc1cc1ccccc11ccccc1cc1cccc777777777777cccccccccccccccccccccccccc66cc66cc88cc88cccccccccccccccccccccccccc
cc2222cccc2222ccccc11cccccc11cccccc11cccccc11ccccc777777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccc777777777777cccccccccbbbbbbbbbbccccccccccccccccccccccccccccbbbbbbccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccc7777777777cccccccccbbbbbbbbbbbbcccccccccccccccccccccccccbbbbbbbbbbccccccccccc
777ccccccccc77cccc777ccccc777ccccccccc77cccc777cccc7777777777ccccccccbbbbbbbbbbbbbbccccccccccccccccccccccbbbbbbbbbbbbbbccccccccc
777cccccccc77ccccc777ccccc777cccccccc77ccccc777ccccc77777777ccccccccbbbbbbbbbbbbbbbbcccccccccccccccccccbbbbbbbbbbbbbbbbbbccccccc
777ccccccc77cccccc777ccccc777ccccccc77cccccc777cccccc777777ccccccccbbbbbbbbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbbbbbbbbbbbbccccc
777cccccc77ccccccc777ccccc777cccccc77ccccccc777ccccccc7777ccccccccbbbbbbbbbbbbbbbbbbbbccccbbbbcccccbbbbbbbbbbbbbbbbbbbbbbbbbbccc
777ccccc77cccccccc777ccccc777ccccc77cccccccc777cccccccc77ccccccccbbbbbbbbbbbbbbbbbbbbbbccbbbbbbccbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc
777cccc77ccccccccc777ccccc777cccc77ccccccccc777cccccccccccccccccbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
777ccc77cccccccccc777ccccc777ccc77cccccccccc777cccccccc7cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
777cc77ccccccccccc777ccccc777cc77ccccccccccc777ccccccc777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
777c77cccccccccccc777ccccc777c77cccccccccccc777cccccc77777cccccccccccccccccccccccbbbbbbccccccccccccccccccccccccccccccddccccccccc
77777ccccccccccccc777ccccc77777ccccccccccccc777ccccc7777cccccccccccccccccccccccbbbbbbbbbbccccccccccccccccccccccccccccddccccccccc
7777cccccccccccccc777ccccc7777cccccccccccccc777cccc777cccccccccccccccccccccccbbbbbbbbbbbbbbcccccccccccccddddddddddddddddcccccccc
7777777777cccccccc777ccccc7777777777cccccccc777ccc77cccccccccccccccccccccccbbbbbbbbbbbbbbbbbbcccccccccccddddddddddddddddcccccccc
777cccc77777cccccc777ccccc777cccc77777cccccc777ccccccccccccccccccccccccccbbbbbbbbbbbbbbbbbbbbbbcccccccccddddddddddddddddcccccccc
777cccccc7777ccccc777ccccc777cccccc7777ccccc777ccccccc777777cccccccccccbbbbbbbbbbbbbbbbbbbbbbbbbbcccccccddddddddddddddddcccccccc
777ccccccc777ccccc777ccccc777ccccccc777ccccc777ccccc777cccc777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
777ccccccc777ccccc777ccccc777ccccccc777ccccc777cccc777cccccc777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
777ccccccc777ccccc777ccccc777ccccccc777ccccc777ccc7777cccccc777ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddc
777ccccccc777ccccc777ccccc777ccccccc777ccccc777ccc7777cccccc777ccccccccccccccccccccccccccccccccccccccccccddccccccccccccccccccddc
777ccccccc777ccccc777ccccc777ccccccc777ccccc777cccc77777ccccccccccccddddddddcccccccccccccccccccccccccccccddcccccccccccccccccdddd
777ccccccc777ccccc777ccccc777ccccccc777ccccc777ccccc77777ccccccccccddddddddddcccccccddddddddcccccccccccddddddddddccccccccccddddd
777ccccccc777ccccc777ccccc777ccccccc777ccccc777ccccccc77777cccccccddddddddddddcccccddddddddddcccccccccddddddddddddccccccccdddddd
777ccccccc777ccccc777ccccc777ccccccc777ccccc777ccccccccc77777ccccddddddddddddddcccddddddddddddcccccccddddddddddddddccccccddddddd
777ccccccc777ccccc777ccccc777ccccccc777ccccc777cccccccccc77777ccccccddddddddccccccccddddddddccccccccccccddddddddcccccccccccccccc
777ccccccc777ccccc777ccccc777ccccccc777ccccc777ccc777cccccc7777cccccddddddddccccccccddddddddccccccccccccddddddddcccccccccccccccc
777ccccccc777ccccc777ccccc777ccccccc777ccccc777ccc777cccccc7777cccccddddddddccccccccddddddddccccccccccccddddddddcccccccccccccccc
777ccccccc777ccccc777ccccc777ccccccc777ccccc777ccc777cccccc777ccccccddddddddccccccccddddddddccccccccccccddddddddcccccccccccccccc
777ccccccc777ccccc777ccccc777ccccccc777ccccc777cccc777cccc777cccccccddddddddccccccccddddddddccccccccccccddddddddcccccccccccccccc
777cccccccc777cccc777ccccc777cccccccc777cccc777cccccc777777cccccccccddddddddccccddddddddddddddddddddddddddddddddcccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddccccddddddddddddddddddddddddddddddddcccccccddccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddccccddddddddddddddddddddddddddddddddccccccddddcccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccc222222222222cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccc222222dd222222ccccccccccccccccccccc888888888888888888888888cccccccccccccccccc88888888888888888888cccccccccccccccccccccc
cccccccc22d2222772222d22cccccccccccccccccc8878887888788888878887888788cccccccccccccc888788888887888888878888cccccccccccccccccccc
ccccccc222722227722227222ccccccccccccccc88887888788878888887888788878888cccccccccc8888777888887778888877788888cccccccccccccccccc
cccccc22222222222222222222cccccccccccc888888888888888888888888888888888888cccccc88888888888888888888888888888888cccccccccccccccc
d777777f7777777777777777777777ff7777777dff777777cccccccccccccc222222222222cccccccccccccccccccccccccccccccccccccccccccccccccccccc
d777777f7777777777777777777777ff7777777dff777777cccccccccccc2222222222222222cccccccccccccccccccccccccccccccccccccccccccccccccccc
d7d77d7f77d77d7777d77d7777d77dff77d77d7dffd77d77cccccccccc22222222222222222222cccccccccccccccccccccccccccccccccccccccccccccccccc
d7d77d7f77d77d7777d77d7f77d77dff77d77d7dffd77d77cccccccc222222277222222772222222cccccccccccccccccccccccccccccc77cccccccccccccccc
d7d77d7f77d77d7777d77d7f77d77dff77d77d7dffd77d77cccccc2222222227722222277222222222cccccccccccccccccccccccccccc77cccccccccccccccc
d77777ff77777777777777ff77777fff777777fdfff77777cccccccc7777777dd777777dd7777777ccccccccccccccc999999999999999999ccccccccccccccc
df7777ff777777777777ffff77777ffff77ffffdfff77777cccccccc777777777777777777777777ccccccccccccc9979979979999799799799ccccccccccccc
ddd777fddddd77ddddddddfddddfffddddfffdddddfffdddcccccccc77d77d7777d77d7777d77d77ccccccccccc99999999999999999999999999ccccccccccc
dffffffffffffffffffffffdccccccccccccccccccccccccccccccccf7d77d77f7d77d7777d77d7fcccccccccccccccccccccccccccccccccccccccccccccccc
dffffffffffffffffffffffdccccccccccccccccccccccccccccccccf7d77d77f7d77d7777d77d7fcccccccccccccccccccccccccccccccccccccccccccccccc
dffffffffffffffffffffffdccccccccccccccccccccccccccccccccff777777ff777f77777777ffcccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccfffff777fff77fff777fffffcccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccccc99999999999999997799999999cccddddfffdddddddffdfffddddcccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccc9799979997999799777799799979cc777777777777777777777777cccccccccccccccccccccccccccccccccccccccccccccccc
ccccccccccccccccccccccccc997999799979997977777797999799c777777777777777777777777cccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccc99999999999999999999999999999999f7d77d7777d77d7777d77d7fcccccccccccccccccccccccccccccccccccccccccccccccc
d777777777777777777777777777777dccccccccccccccccccccccccf7d77d77f7d77d7777d77d7fcccccccccccccccccccccccccccccccccccccccccccccccc
d77d77d777d77d7777d77d777d77d77dccccccccccccccccccccccccf7d77d77f7d77d7777d77d7fcccccccccccccccccccccccccccccccccccccccccccccccc
df7d77d77fdf7d7777d7fd777d77d77dccccccccccccccccccccccccff777777ff777f77777777ffcccccccccccccccccccccccccccccccccccccccccccccccc
dfffff777ffffff7777fff77777777fdccccccccccccccccccccccccfffff777fff77fff777fffffcccccccccccccccccccccccccccccccccccccccccccccccc
ddddddfddddddddffdddddffd7ddddddccccccccccccccccccccccccddddfffdddddddffdfffddddcccccccccccccccccccccccccccccccccccccccccccccccc
d777777777777777777777777777777dccccccccccccccccccccccccf7777777777777777777777fcccccccccccccccccccccccccccccccccccccccccccccccc
d77d77d77fd77d7777d77d777d77d77dccccccccccccccccccccccccff777777f777777f777777ffcccccccccccccccccccccccccccccccccccccccccccccccc
d7fd77d77fd77d77f7d77d777d77df7dccccccccccccccccccccccccffff777fff777ffff777ffffcccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000060616263000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000006a6d00000000000000717100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000061620000000000000000000000000000000000000000000000000000000000000000000000
000000606162630070746d00000000000070717c7e000000000000000000000083848486000000000083858600000000616200000000000000008386000000000000007b7c7d7c7d7c7d7e0000000000000000000000008385860071710000000000000000007778787900007b7c7d7e00000000000083858485860000000000
0000000075720000707174000000000000707274740000000000000000000000978997870000000000879889616200007074000000006566666890930000000000000000707173727174777878787900000000000000009092930075720000000000000000008787888800000071716767676800000090929292930000000000
6566666673717c7c717274848585858586727274756767676767687778787878979999976b6b6b6b6d8787879093848470747c7c7d7e73737272909378787878796a6b6b70717171737487879887876b6b6d7b7c7c7d7e9092936c7572787878787985848586888889896c6c6c71717071757478787890919192936b6b6b6b6d
7173717170747174727173737373737171717171717172717171727271717171979997979091919193979797909398987074717171717071717190937171717171707171707371717374979798979971717171717171719091937171719999989897717171719798989971717175717071727497989990919191937171717171
8081818180828181808182818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000006a6b6b6b6b6d000000000000000000000000000000838484848600000000000000000000000000000000000000000000000000000000000000000000000000000000000000007171000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000707171757174000000000061620000007778787878707171717400000000000000000000000000000000007171717100000000000000717100000071710000007171000000007171000000000000007171717100000000000071710000000071740000000070740000000000000070717400717400000000000000
77787878787271727575747c7d7c7d7c70718485848788888899707171717400000000000000007171717100000000007171717100000000000000717171717171717171007171007171717171717171000000007171717100000000000071710000000071740000000070747174000000000070737400717400000000000000
7171717171707173727174717171717170717071719798989899707171717471717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171747171717171747174717171717170737471707471717171717171
8181818181808181818182818181818180818081818081818181808181818281818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818180828181818180828182818181818180818281808281818181818181
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000484900000000004c4d5c4e00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000005e5c5f0000000000000000005d5d5c4d4e0000005d5d0000000000005e4d5c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000483e3d3e3d490000004f3e0000004c4d5c5c4d4b0000004c4d5c4e00000000000000005d000000000000000000485d5d5d5d000000005d5d4849000000483d5d5d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000585d5d5d5d590000005d5d5c4b00005d5d5d5d59000000005d5d0000484900000000005d5d5d4b0000000000005d5d5d5d5d000000005d5d5d5d000000585d5d5d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4a5c5c5c5a5d5d5d5d5b5c5f5e5d5d5d5b5f005d5d5d5d5b5c5c5c5f5d5d5c5c5a5900000000005d5d5d5b5c5c5f005e5c5d5d5d5d5d00005e5c5d5d5d5d5c5c5c5a5d5d5d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000002b00000000000000000000002b000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000028292a00000000000000000028292a0000000000002c2d2e2f393a3b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000282929292a2c2d2e2f393a3b282929292a0000002c2d292929292929292e2f00002c2d2e2f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
002829292929292929292929292929292929292a2c2d29292929292929292929292e2d292929290000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2829292929292929292929292929292929292929292929292929292929292929292929292929290000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
354600002213422130221352111421110241242212422120221202212022120221251f1141f1101f1151e1241e125201441f1141f1101f1101f1101f1101f1151b1441b1401b1451a1141a1101d1441b1341b130
494600001b73022740227451b73021740217451b73022740227451a7501d7401d745187301f7401f745187301e74020750187301f7401f745167301a7401a745147301b7401b745147501a7401a745137301b740
354610001b1451a1241b1341d1441f1441f1451d1341d1341d135181341d1441d1401d1401d1401d1401d14500000000000000000000000000000000000000000000000000000000000000000000000000000000
494610001b7350f7201b7301b735117201d7301d735117202173021735117201d7301b7301a7401b7401d74500000000000000000000000000000000000000000000000000000000000000000000000000000000
6701002002a2002a2003a2003a2003a2003a2002a2002a2002a2002a2002a2002a2003a2003a2003a2000a2001a2001a2002a2002a2002a2001a2001a2000a2000a2000a2002a2003a2001a2000a2000a2000a20
__music__
01 00014344
02 02034344

