// A lot of this code is old and terrible, it's just used here as a demonstration

const toothWidth = 30;
const toothGap = 26;
const toothTaper = 0.8; //Tooth gap should be slightly larger than tooth taper multiplied by tooth width
const toothDepth = 30;

const cogsCVS = document.getElementById("cogs");
const cogsCTX = cogsCVS.getContext("2d");

let cogs = [];

function createCog(x, y, numberOfTeeth, thickness, spokes, spokeThickness, colour, direction) {
  return {
    x,
    y,
    numberOfTeeth,
    size: numberOfTeeth * (toothWidth+toothGap) / Math.PI / 2,
    thickness,
    spokes,
    spokeThickness,
    colour,
    direction,
    offset: 0
  };
};

function drawCog(cog, time)
{
  const {
    x,
    y,
    offset,
    numberOfTeeth,
    size,
    thickness,
    spokes,
    spokeThickness,
    colour,
    direction
  } = cog;
	////////////Some Maths/////////////
	const circumference = 2*Math.PI*size;
  const outerSize = size+toothDepth/2;
	const outerCircumference = 2*Math.PI*outerSize;
  const innerSize = size-toothDepth/2;
  const innerCircumference = 2*Math.PI*innerSize;
	const baseToothAngle = 2*Math.PI*toothWidth/innerCircumference/2;
	const topToothAngle = 2*Math.PI*toothWidth*toothTaper/outerCircumference/2;
	//Increase gaps in size slightly in order to fudge fractional values
	//console.log(numberOfTeeth);
	const totalToothWidth = numberOfTeeth*toothWidth;
	const totalGapWidth = circumference-totalToothWidth;
	const gapSize = totalGapWidth/numberOfTeeth;
	
	const rotation = time*direction/numberOfTeeth;
	
	////////////Draw Circle////////////
	cogsCTX.beginPath();
	cogsCTX.arc(x,y,innerSize-(thickness/2),0,2*Math.PI, false);
	cogsCTX.lineWidth = thickness;
	cogsCTX.strokeStyle = colour;
	cogsCTX.stroke();
	
	////////////Draw Spokes////////////
	spokeInterval = 2*Math.PI/spokes;
	spokeLength = innerSize-(thickness/4);
	for(i=0;i<spokes;i++)
	{
		angle = spokeInterval*i+rotation;
		xOffset = spokeLength*Math.cos(angle);
		yOffset = spokeLength*Math.sin(angle);
		cogsCTX.beginPath();
		cogsCTX.lineWidth = spokeThickness;
		cogsCTX.moveTo(x,y);
		cogsCTX.lineTo(x+xOffset,y+yOffset);
		cogsCTX.stroke();
	}
	
	////////////Draw Teeth////////////	
	toothInterval = 2*Math.PI/numberOfTeeth;
	for(i=0;i<numberOfTeeth;i++)
	{
		angle = toothInterval*i+rotation + offset;
		x1 = x+innerSize*Math.cos(angle-baseToothAngle);
		y1 = y+innerSize*Math.sin(angle-baseToothAngle);
		x2 = x+innerSize*Math.cos(angle+baseToothAngle);
		y2 = y+innerSize*Math.sin(angle+baseToothAngle);
		x4 = x+outerSize*Math.cos(angle-topToothAngle);
		y4 = y+outerSize*Math.sin(angle-topToothAngle);
		x3 = x+outerSize*Math.cos(angle+topToothAngle);
		y3 = y+outerSize*Math.sin(angle+topToothAngle);
		cogsCTX.beginPath();
		cogsCTX.moveTo(x1,y1);
		cogsCTX.lineTo(x2,y2);
		cogsCTX.lineTo(x3,y3);
		cogsCTX.lineTo(x4,y4);
		cogsCTX.closePath();
		cogsCTX.fillStyle = colour;
		cogsCTX.fill();
	}
}

function calculateOffset(parentCog, childCog) {
  const angleFromParentToChild = Math.atan2(childCog.y - parentCog.y, childCog.x - parentCog.x);
  const parentToothAngularPeriod = Math.PI * 2 / parentCog.numberOfTeeth;
  const parentConnectionToothIndex = (angleFromParentToChild - parentCog.offset) / parentToothAngularPeriod;
  const childToothIndex = parentConnectionToothIndex + 0.5;
  const childToothAngularPeriod = Math.PI * 2 / childCog.numberOfTeeth;
  const childOffset = childToothIndex * childToothAngularPeriod + angleFromParentToChild + Math.PI;
  console.log({
    angleFromParentToChild,
    parentToothAngularPeriod,
    parentConnectionToothIndex,
    childToothIndex,
    childToothAngularPeriod,
    childOffset
  });
  return childOffset;
}

function init() {
  cogs = [];
  let numberOfTeeth = 10;
  let direction = 1;
  let cog = createCog(128, 256, numberOfTeeth, 20, 5, 10, "black", direction);
  let oldDiameter = numberOfTeeth * (toothWidth+toothGap) / Math.PI;
  cogs.push(cog);
  for(let i = 0; i < 10; i++) {
    direction *= -1;
    let angle = (Math.random() - 0.5) * Math.PI / 2;
    let numberOfTeeth = Math.round(6 + Math.random() * 12);
    let radius = numberOfTeeth * (toothWidth+toothGap) / Math.PI / 2;
    let distance = cog.size + radius;
    let x = cog.x + Math.cos(angle) * distance;
    let y = cog.y + Math.sin(angle) * distance;
    let newCog = createCog(x, y, numberOfTeeth, 20, 5, 10, "black", direction);
    newCog.offset = calculateOffset(cog, newCog);
    cogs.push(newCog);
    cog = newCog;
  }
}


function draw(now) {
  //let time = 0;
  let time = now / 100;
  cogsCVS.width = cogsCVS.width; // Clear canvas
  //drawCog(createCog(128, 128, 0, 10, 20, 5, 10, "black"), time);
  for(let i = 0; i < cogs.length; i++) {
    drawCog(cogs[i], time);
  }
  requestAnimationFrame(draw);
}

init();
requestAnimationFrame(draw);