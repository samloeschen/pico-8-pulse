------------------------
---------pico-8---------
------------------------

function _init()
	ship.pos=newvec(4,4)
end

function _update60()
	--update current input
	updateinput()
	ship.update()
	updatepulses()
	
	for i=1, #ctiles do
		local t=ctiles[i]
			if(t != nil) then
				t:update()
			end
	end
	
	--move camera
	camera(ship.pos.x-64, ship.pos.y-64)
end

function _draw()
	--draw background
	rectfill(ship.pos.x-128,
	ship.pos.y - 128,
	ship.pos.x + 128,
	ship.pos.y + 128,
	0)
	
	--draw pulses
	drawpulses()
	
	--draw tiles
	drawtiles()
	
	ship.drw()
end

------------------------
--------vectors---------
------------------------

vt={}
function newvec(x,y)
	local v={
		x=x,
		y=y
	}
	setmetatable(v,vt)
	return v
end
function vt.__add(a,b)
	return newvec(
		a.x+b.x,
		a.y+b.y
	)
end
function vt.__sub(a,b)
	return newvec(
		a.x-b.x,
		a.y-b.y
	)
end
function vt.__eq(a,b)
	return a.x==b.x and a.y==b.y
end
function vt.__mul(a,b)
	if type(a) == "number" then
 	return newvec(b.x*a,b.y*a)
 elseif type(b) == "number" then
 	return newvec(a.x*b,a.y*b)
 end
 	return a.x*b.x+a.y*b.y
end

local vecmethods={}
function vecmethods.magnitude(self)
	return(fastsqrt(self.x^2+self.y^2))
end
function vecmethods.normalize(self)
	len_sq=(self.x^2)+(self.y^2)
	len_inv=fastsqrt(len_sq)
	return newvec(
		self.x * len_inv,
		self.y * len_inv)
end
function vecmethods.screen2map(self)
	return newvec(flr(self.x/8),
		flr(self.y/8))
end
function vecmethods.map2screen(self)
	return newvec(self.x*8,
	self.y*8)
end
--put vec methods in the vector metatable	
vt.__index=vecmethods
function fastsqrt(x)
	a0=15/8
	a1=-5/4
	a2=3/8
	return (a0 + a1 * x + a2 * x * x)
end


------------------------
----------ship----------
------------------------

rotaccel=0.02
linaccel=0.02
maxlinvel=0.98
rotdir=0
rotdir=0
ship={
	pos=newvec(0,0),
	vel=newvec(0,0),
	rot=0,
	velrot=0
}
ship.drw=function()
	local r=flr(ship.rot*20)/20
	local s=sin(r)
	local c=cos(r)
	local b=s*s+c*c
	for y=-4,4 do
		for x=-4,4 do
			local ox=(s*y+c*x)/b+4
			local oy=(-s*x+c*y)/b+4
			local col=sget(ox,oy)
			if col>0 then
				px=ship.pos+newvec(x,y)
			 pset(px.x,px.y,col)
			end
		end
	end
end
ship.update = function()
	--update rotation
	ship.rot+=rotaccel*rotdir
	if ship.rot>1 then ship.rot=0 end
	if ship.rot<0 then ship.rot=1 end
	
	--update movement
	if btn(2) then
		local v=newvec(
			sin(ship.rot),
			-cos(ship.rot)
		)
		v=v:normalize()*linaccel
		ship.vel+=v
		if ship.vel:magnitude()
			>maxlinvel then
				ship.vel:normalize()
				ship.vel*=maxlinvel
		end		
	end
		--clamp max velocity
	ship.pos+=ship.vel
end

function updateinput()
	--pulse charging
	if(state==pstate.wait)then
  if btn(4) then
   state=pstate.charge
  end
	elseif(state==pstate.charge)then
	 charge+=chargerate
	 if not btn(4) then
	  state=pstate.pulse
	 end
	elseif(state==pstate.pulse)then
	 local r=lerp(minrad,
	  maxrad,
	  charge)
	 newpulse(ship.pos,r)
	 state=pstate.wait
	 charge=0
	end
	--ship rotation
	if btn(0) then rotdir=1
	elseif btn(1) then rotdir=-1
	else rotdir=0 end
end


------------------------
---------pulses---------
------------------------


pstate={
	wait=1,
	charge=2,
	pulse=3
}
state=1

--pulsecolor
pulsecol = 7
--charging
chargerate=0.01
--how quickly pulse accelerates
pulseaccel=0.01
--charge
charge=0
--radius
minrad=10
maxrad=100
pulses={} --pulse array
pulsecolors={7,6,5,2,1,0}

function newpulse(pos,radius)
	local p={}
	p.col=1
	p.r=0 --cradius
	p.maxr=radius
	p.pos=pos
	if #pulses<1 then
		pulses[1]=p
	elseif #pulses>=1 then
			add(pulses, p)
	end
end

function updatepulses()
	for i=1, #pulses do
		local p=pulses[i]
		if(p != nil) then
			if p.r<p.maxr then
			 p.r+=lerp(5,0.1,p.r/p.maxr)
			 getvisible(p)
			else
				p.col+=0.4
				if(p.col>#pulsecolors) then
					del(pulses, p)
				end
			end
		end
	end
end
function getvisible(p)
	local x=(p.r/8) --ceil radius
	local y=0
	local err=0
	local pos=p.pos:screen2map()
	while x>=y do
		checkmap(pos.x+x,pos.y+y)
		checkmap(pos.x+y,pos.y+x)
		checkmap(pos.x-y,pos.y+x)
		checkmap(pos.x-x,pos.y+y)
		checkmap(pos.x-x,pos.y-y)
		checkmap(pos.x-y,pos.y-x)
		checkmap(pos.x+y,pos.y-x)
		checkmap(pos.x+x,pos.y-y)
		if(err<=0) then
			y+=0.5
			err+=2*y+0.9
		elseif(err>0) then
			x-=0.5
			err-=2*x+0.9
		end
	end
end

function checkmap(x,y)
	if(mget(x,y)==2) then
		for i=1, #ctiles do
			if(ctiles[i].x==x and 
				ctiles[i].y==y) then
				return --early exit if duplicate
			end
		end
		tile.new(newvec(flr(x),flr(y)))
	end
end

function drawpulses()
	for i=1, #pulses do
		local p=pulses[i]
		circ(p.pos.x,
   p.pos.y,
   p.r,
   pulsecolors[flr(p.col)])
	end
end

------------------------
---------tiles----------
------------------------

ctiles={}
tile={}
fadetime=0.4

tile.new=function(mappos)
	local self={}
	self.pos=mappos
	self.t=0
	self.rate=rnd(0.005)+0.016
	self.life=2
	self.update=tile.update
	self.draw=tile.draw
	add(ctiles,self)
	return self
end
tile.update=function(self)
 self.t+=self.rate
 if self.t>self.life then
 	del(ctiles,self)
 end
end
tile.draw=function(self)
	local v=self.pos
	local cols={0,1,2,5,13,6,7,7}
	if self.t>=0 then
		l=lerp(1,#cols, self.t/fadetime)
		col=cols[flr(l)]
	end
	if self.t>=self.life-fadetime then
		l=lerp(1,#cols, (self.life-self.t)/fadetime)
		col=cols[flr(l)]
	end
	rectfill(flr((v.x-0.5)*8),
		flr((v.y-0.5)*8),
		flr((v.x+0.5)*8),
		flr((v.y+0.5)*8),
		col)
end 
function drawtiles()
	for i=1, #ctiles do
		local t=ctiles[i]
			ctiles[i]:draw()
	end
end
	


------maff------

function lerp(a,b,t)
	if(t>1)t=1
	if(t<0)t=0
	return(1-t)*a+t*b
end
