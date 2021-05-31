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


    -- set camera position
    move_camera(kiki["x"], kiki["y"], not move, kiki["mirror"])

    -- add in new pickup and drop off's randomly
    -- TODO: don't spawn too close to the player
    -- TODO: make sure to spawn the drop off spot a little ways from the player
    -- TODO: don't spawn pickup and drop off spots too close to each other
    if flr(rnd(60 * 3)) == 1 then
        add(orders, new_order(rnd(1024), rnd(1024)))
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

    print(_debug, 5, 15, red)
    _debug = ""

    camera(cam["x"], cam["y"])
    do_day_cycle(frames)

    -- draw the map. we'll probably end up wanting to use one of these sections
    -- for the paralax bg. It will be ok to repeat it more because it will scroll much
    -- more slowly
    map(0, 0, 0, 64, 128, 8)
    map(0, 8, 1024, 64, 128, 8)
    -- map(0, 16, 2048, 64, 128, 8)
    -- map(0, 24, 3072, 64, 128, 8)

    -- draw pickup/ dropoff
    for _, order in ipairs(orders) do
        if order["got"] then
            spr(11, order["dropoff"], 100)
        else
            spr(12, order["pickup"], 100)
        end
    end

    -- draw kiki
    palt(black, false)
    palt(blue, true)
    if kiki["d_frames"] > 0 then
        if frames%4 == 0 then
            spr(1, kiki["x"], kiki["y"]+sin(frames/60)*1.5, 1, 1, kiki["mirror"], false)
        end
    else
        spr(1, kiki["x"], kiki["y"]+sin(frames/60)*1.5, 1, 1, kiki["mirror"], false)
    end

    -- draw planes
    for _, plane in ipairs(planes) do
        spr(2, plane["x"], plane["y"], 2, 1, plane["mirror"], false)
    end

    -- draw birds
    for _, bird in ipairs(birds) do
        spr(6, bird["x"], bird["y"], 1, 1, bird["mirror"], false)
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
end

function update_main_menu()
    if btnp(❎) or btnp(🅾️) then
        delivered = 0
        draw_fn = draw_gameplay
        update_fn = update_gameplay

        music(-1, 300)
    end
end

function draw_main_menu()
    cls(blue)
    print("kiki's delivery service", 18, 20, red)

    print("press ❎/🅾️ to start", 22, 90, red)
end

-->8
-- ui
function draw_dash_ui()
    if kiki["dash_cd"] <= 0 then
        spr(13, 5, 5)
    end
end

function draw_weight_ui()
    for i=1,kiki["carry_weight"],1 do
        spr(14, 100+i*4, 5)
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
cccc442cccccccccccc11cccccc11cccccc11ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cc4442cccc22222cc11cc11ccc1cc1ccccc11ccccccccccccccccc7777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
c242222c22444422c1c11c1ccc1111ccccc11ccccccccccccccc77777777cccccc1c1ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
24222242242222421c111cc1c1c11c1cccc11cccccccccccccc7777777777ccccc1c1ccc1ccccc1cc11c11cccccccccccccccccccccccccccccccccccccccccc
24442422244424221c1111c1c1c11c1cccc11cccccccccccccc7777777777ccccc1c1cccc11c11cc1cc1cc1ccccccccccccccccccccccccccccccccccccccccc
2444224224442242c1cccc1ccc1cc1ccccc11ccccccccccccc777777777777ccccc1ccccccc1cccccccccccccccccccccccccccccccccccccccccccccccccccc
2244242c2244242cc11cc11ccc1cc1ccccc11ccccccccccccc777777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cc2222cccc2222ccccc11cccccc11cccccc11ccccccccccccc777777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccc777777777777cccccccccbbbbbbbbbbccccccccccccccccccccccccccccbbbbbbccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccc7777777777cccccccccbbbbbbbbbbbbcccccccccccccccccccccccccbbbbbbbbbbccccccccccc
777ccccccccc77cccc777ccccc777ccccccccc77cccc777cccc7777777777ccccccccbbbbbbbbbbbbbbccccccccccccccccccccccbbbbbbbbbbbbbbccccccccc
777cccccccc77ccccc777ccccc777cccccccc77ccccc777ccccc77777777ccccccccbbbbbbbbbbbbbbbbcccccccccccccccccccbbbbbbbbbbbbbbbbbbccccccc
777ccccccc77cccccc777ccccc777ccccccc77cccccc777cccccc777777ccccccccbbbbbbbbbbbbbbbbbbccccccccccccccccbbbbbbbbbbbbbbbbbbbbbbccccc
777cccccc77ccccccc777ccccc777cccccc77ccccccc777ccccccc7777ccccccccbbbbbbbbbbbbbbbbbbbbccccbbbbcccccbbbbbbbbbbbbbbbbbbbbbbbbbbccc
777ccccc77cccccccc777ccccc777ccccc77cccccccc777cccccccc77ccccccccbbbbbbbbbbbbbbbbbbbbbbccbbbbbbccbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbc
777cccc77ccccccccc777ccccc777cccc77ccccccccc777cccccccccccccccccbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
777ccc77cccccccccc777ccccc777ccc77cccccccccc777cccccccc7ccccccccccccccccccccccccccccccccccccccccccccccccbbbbbbbbcccccccccccccccc
777cc77ccccccccccc777ccccc777cc77ccccccccccc777ccccccc777cccccccccccccccccccccccccccccccccccccccccccccccbbbbbbbbcccccccccccccccc
777c77cccccccccccc777ccccc777c77cccccccccccc777cccccc77777cccccccccccccccccccccccbbbbbbcccccccccccccccccbbbbbbbbcccccccccccccccc
77777ccccccccccccc777ccccc77777ccccccccccccc777ccccc7777cccccccccccccccccccccccbbbbbbbbbbcccccccccccccccbbbbbbbbcccccccccccccccc
7777cccccccccccccc777ccccc7777cccccccccccccc777cccc777cccccccccccccccccccccccbbbbbbbbbbbbbbcccccccccccccbbbbbbbbccccccccdddddddd
7777777777cccccccc777ccccc7777777777cccccccc777ccc77cccccccccccccccccccccccbbbbbbbbbbbbbbbbbbcccccccccccbbbbbbbbccccccccdddddddd
777cccc77777cccccc777ccccc777cccc77777cccccc777ccccccccccccccccccccccccccbbbbbbbbbbbbbbbbbbbbbbcccccccccbbbbbbbbccccccccdddddddd
777cccccc7777ccccc777ccccc777cccccc7777ccccc777ccccccc777777cccccccccccbbbbbbbbbbbbbbbbbbbbbbbbbbcccccccbbbbbbbbccccccccdddddddd
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
0900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0900000000000000000000000000000000090a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0900000000000000000000000000000000191a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
09000000090a0000090a00000000000000090a090a0000000000000000000000090a090a00000000000000090a000000090a0000000000000000090a0000000000000000090a090a090a0000090a090a090a00090a0000090a090a0000000000000000000000090a090a000000090a00000000090a0000090a090a0000000000
09000000191a0000191a00000000000000191a191a0000000000000000000000191a191a00000000000000191a000000191a090a090a090a090a19090a090a090a000000191a191a191a0000191a191a191a00191a0000191a191a0000000000000000000000191a191a000000191a00000000191a0000191a191a0000000000
090a090a090a090a09090a090a090a090a090a090a090a090a090a09090a090a090a09090a090a090a09090a090a090a090a191a090a090a090a0919090a090a090a090a090a090a090a090a090a090a09090a090a090a090a090a090a090a090a090a09090a090a09090a090a090a090a090a090a090a090a09090a090a090a
191a191a191a191a19191a191a191a191a191a191a191a191a191a19191a191a191a19191a191a191a19191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a19191a191a191a191a191a191a191a191a191a19191a191a19191a191a191a191a191a191a191a191a19191a191a191a
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009
0000000000090a090a090a00000000000000000000000000000009090a090a0000000000000000000000000000000000090a090a0000000000000000000000000000000000090a0000000000000000000000000000000000000000000000090a00000000090a0000000000000000000000000000000000090a00000000000009
0000000000191a191a191a00000000000000000000090a090a090a191a191a0000000000000000090a090a0000000000191a191a0000000000000009090a0a090a090a0a00191a00090a090a090a090a00000000090a090a000000000000191a00000000191a00000000090a090a000000000000000000191a00000000000009
090a09090a090909090909090a0a090a090a090a09191a191a191a090909090a0a0a090a090a09191a191a090a090a09090a090a090a09090a090a19090a090a09191a0a0a090a09191a191a191a19090a090a09191a191a0a090a090a0909090a0a090a09090909090a191a191a090a090a090a090a0909090a090a090a090a
191a19191a191919191919191a1a191a191a191a191a191a191a19191919191a1a1a191a191a191a191a19191a191a19191a191a191a19191a191a19191a191a191a191a1a191a191a191a191a191a191a191a191a191a191a191a191a1919191a1a191a19191919191a191a191a191a191a191a191a1919191a191a191a191a
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d5d0000000000005d5d0000005d5d0000000000000000000000000000000000000000000000000000000000000000000000000000004c4d5c4e0000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000005d5d5d5d000000005d5d0000005d5d00000000000000005d5d000000000000000000000000000000004f3f3f49000000000000000000005d5d00000000004a4d5c5c5c4b000000005e5c5c5f0000
00000000005d5d5d5d000000005d5d000000005d5d5d5d00000000005d5d00005d5d00000000005d5d5d5d0000000000005d5d5d5d5d000000005d5d0000005d5d00000000000000005d5d000000005d00000000000000004f4b00585d5d5b4b0000000000000000005d5d000000004a5a5d5d5d5d5900000000005d5d000000
00000000005d5d5d5d000000005d5d000000005d5d5d5d00000000005d5d00005d5d00000000005d5d5d5d0000000000005d5d5d5d5d000000005d5d0000005d5d5d5d5d5d5d5d005d5d5d5d5d5d5d5d000000000000004a5d5d5d5d5d5d5d5b5c5c5f0000000000005d5d00000000585d5d5d5d5d5900000000005d5d000000
5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d
5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d5d
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009
0000090a090a090a00000000000000000000000000000000090a090a090a00000000000000000000000000000000000000090a090a0000090a000000000000000000000000000000000000090a090a000000000000090a090a090a000000090a090a000000000000000000000000090a090a00000000090a0000000000000009
0000191a191a191a00000000000000000000000000000000191a191a191a00000000000000000000000000000000000000191a191a0000191a000000000000000000000000000000000000191a191a000000000000191a191a191a000000191a191a000000000000000000000000191a191a00000000191a0000000000000009
090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a09090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a09090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a090a0909
191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a19191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a19191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a191a
__sfx__
354600002213422130221352111421110241242212422120221202212022120221251f1141f1101f1151e1241e125201441f1141f1101f1101f1101f1101f1151b1441b1401b1451a1141a1101d1441b1341b130
494600001b73022740227451b73021740217451b73022740227451a7501d7401d745187301f7401f745187301e74020750187301f7401f745167301a7401a745147301b7401b745147501a7401a745137301b740
354610001b1451a1241b1341d1441f1441f1451d1341d1341d135181341d1441d1401d1401d1401d1401d14500000000000000000000000000000000000000000000000000000000000000000000000000000000
494610001b7350f7201b7301b735117201d7301d735117202173021735117201d7301b7301a7401b7401d74500000000000000000000000000000000000000000000000000000000000000000000000000000000
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 00014344
02 02034344

