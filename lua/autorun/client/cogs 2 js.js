function Gear(n){
	this.v=[];
	var f=n/12,a=f*1.91,t=0.525/f,r=f*10,p=0.45+0.25*Math.PI/n;
	//var f=n/24,a=f*3.82,t=0.259/f,r=f*10,p=0.45+0.40*Math.PI/n;
	for (var i=0;i<n;i++){
		var vt = this.toothVerts(i/a,t,r,1.0,1.0,p);
		for (var j in vt)
			this.v.push(vt[j]);
	}
	this.radius = r;
};
Gear.prototype = {
	toothVerts: function(a,t,r,ad,de,pa,pd){
	    var a1 = a+t/4,
	        a2 = a+3*t/4,
		c1 = Math.cos(a1),
		c2 = Math.cos(a2),
		s1 = Math.sin(a1),
		s2 = Math.sin(a2),
		ra = r+ad,
		rd = r-de,
		pa = Math.atan(ad*Math.tan(pa)/ra),
		pd = Math.atan(ad*Math.tan(pa)/ra);
	    if (r < 0)
		pa = -pa
		var ca1 = Math.cos(a+t/4+pa),
		    ca2 = Math.cos(a+3*t/4-pa),
		    sa1 = Math.sin(a+t/4+pa),
		    sa2 = Math.sin(a+3*t/4-pa),
		    cd1 = Math.cos(a+t/4-pa/2),
		    cd2 = Math.cos(a+3*t/4+pa/2),
		    sd1 = Math.sin(a+t/4-pa/2),
		    sd2 = Math.sin(a+3*t/4+pa/2);
		return [
			[rd*Math.cos(a),rd*Math.sin(a)],
			[rd*cd1, rd*sd1],
			[r * c1, r * s1],
			[ra*ca1, ra*sa1],
			[ra*ca2, ra*sa2],
			[r * c2, r * s2],
			[rd*cd2, rd*sd2]
		];
	},
	rotate: function(a){
		var vl=this.v;
		var ca=Math.cos(a),sa=Math.sin(a);
		for (var i in vl){
			var v = vl[i];
			x = v[0]*ca-v[1]*sa; 
			v[1] = v[0]*sa+v[1]*ca; 
			v[0]=x;
		}
		return this;
	},
	translate: function(x,y){
		var vl = this.v;
		for (var i in vl){
			vl[i][0]+=x;
			vl[i][1]+=y;
		}
		return this;
	},
	scale: function(s){
		var vl = this.v;
		for (var i in vl){
			vl[i][0]*=s;
			vl[i][1]*=s;
		}
		return this;
	}
};

GearView = {
	scale: 10,
	speed: 0.2,
	list:[],
	mpos: {x:0,y:0},
	setPos: function(x,y) {
		this.mpos.x = x;
		this.mpos.y = y;
		this.dragging = this.list[this.list.length-1];
		this.dragging.x = x;
		this.dragging.y = y;
		var nearest = undefined,nearestD = 9999;
		for (var i in this.list) {
			var li = this.list[i];
			if (li!==this.dragging) {
				var dx = x-li.x, dy = y-li.y,
					d = Math.sqrt(dx*dx+dy*dy),
					dg = this.scale*(li.g.radius+this.dragging.g.radius);
				if (d-dg<30){
					if (dg-d<nearestD){
						nearest = li;
						nearestD = dg;
						nearestA = Math.atan2(dy,dx);
					}	
				}
			}
				
		}
		if (typeof nearest!=='undefined') {
			//console.log(x+','+y);
			var ndx = nearestD*Math.cos(nearestA),
				ndy = nearestD*Math.sin(nearestA);
			this.dragging.x = nearest.x+ndx;
			this.dragging.y = nearest.y+ndy;
			this.dragging.d = typeof nearest.d==='undefined'?undefined:!nearest.d;
			var f = nearest.g.radius/this.dragging.g.radius;
			var a = (
				-this.dragging.r
				-(f*nearest.r)
				+((1+f)*nearestA)
				+((this.dragging.n+1)%2)*Math.PI/this.dragging.n
			);
			this.dragging.g.rotate(a);
			this.dragging.r += a; 
		} else {
			this.dragging.d = undefined;
		}
		return this;
	},
	add: function(n,d,r,x,y){
		var gear = {
			g: new Gear(n).scale(this.scale).rotate(r),
			n: n,
			d: d,
			r: r*this.scale,
			x: x*this.scale,
			y: y*this.scale
		};
		this.list.push(gear);
		//this.setPos(gear.x,gear.y);
		return this;
	},
	draw: function(){
		if (!this.ctx){
			var canvas = document.getElementById('canvas');
			this.dim = {
				x: canvas.width,
				y: canvas.height
			};
			this.ctx = canvas.getContext('2d');
			this.ctx.fillStyle = '#def';
			this.ctx.strokeStyle = '#000';
		}
		this.ctx.fillStyle = '#def';
		this.ctx.fillRect(0, 0, this.dim.x,this.dim.y);
		for (var i in this.list)
			this.drawSingle(this.list[i]);
		return this;
	},
	drawSingle: function(gear){
		var ctx=this.ctx,v=gear.g.v,x=gear.x,y=gear.y;
		ctx.fillStyle = gear===this.list[this.list.length-1]?'#48a':'#246';
		ctx.strokeStyle = '#a84';
		ctx.beginPath();
		ctx.moveTo(v[0][0]+x,v[0][1]+y);
		for (var i=1;i<v.length;i++)
			ctx.lineTo(v[i][0]+x,v[i][1]+y);
		ctx.closePath();
		ctx.fill();
		ctx.fillStyle = '#def';
		ctx.beginPath();
		ctx.arc(x, y, 1, 0, Math.PI*2, true); 
		ctx.closePath();
		ctx.fill();
		/*
		ctx.beginPath();
		ctx.arc(x, y, gear.n/1.2*this.scale, 0, Math.PI*2, true); 
		ctx.closePath();
		ctx.stroke();
		*/
		return this;
	},
	step: function(){
		for (var i in this.list){
			var li=this.list[i];
			if (typeof li.d!=='undefined') {
				var g = li.g,a=li.d?this.speed/li.n:-this.speed/li.n;
				g.rotate(a);
				li.r+=a;
			}
		}
		this.draw();
	},
	anim: function(){
		var self = this;
		this.timer = window.setInterval(function(){
			self.step();
		},30);	
		return this;
	},
	inc: function(){
		return this.addTeeth(1);
	},
	dec: function(){
		return this.addTeeth(-1);
	},
	addTeeth: function(n){
		var g = this.list.pop(),
			nn = Modifier.teeth(g.n,n);
		this.add(nn,g.d,0,g.x,g.y);
		this.setPos(g.x,g.y);
		return this;
	},
};

Modifier = {
	add: function(n,d){
		return n+d<2?2:n+d;
	},
	mult: function(n,d){
		var nn = d<0
			? n-1+(~~(n*d*0.1))
			: n+1+(~~(n*d*0.1));
		return nn<2?2:nn;
	}
};
Modifier.teeth = Modifier.add;

$(function(){
	A();
	var jw=$(window),w=jw.width(),h=jw.height(),ox=(w/10)>>1, oy=(h/10)>>1;
	$('#canvas').height(h).width(w).attr('width',w).attr('height',h);
	GearView.add(9,true,0,ox,oy)
		.add(6,undefined,0,ox-14,oy)
		.anim()
		.setPos(w-100>>1,h>>1);
	$(document).keydown(function(e){
		if (e.keyCode===16)
			Modifier.teeth = Modifier.mult;
	}).keyup(function(e){
		//console.log(e.keyCode);
		if (e.keyCode===16)
			Modifier.teeth = Modifier.add;
		if (e.keyCode===187)
			GearView.speed+=0.02;
		else if (e.keyCode===189)
			GearView.speed-=0.02;
		else if (e.keyCode===190)
			GearView.inc();
		else if (e.keyCode===188)
			GearView.dec();
	}).mousewheel(function(e,d,dx,dy) {
		GearView.addTeeth(d);
		GearView.setPos(e.clientX,e.clientY);
	});
	$('#canvas').mousemove(function(e){
		GearView.setPos(e.clientX,e.clientY);
	}).click(function(e){
		var g = GearView.list[GearView.list.length-1];;
		GearView.add(6,g.d,0,g.x,g.y);
		GearView.setPos(e.clientX,e.clientY);
	});
});