float shortEdge;
float layoutScale;
float margin;
float arrowHeadSize;
int labelTextSize;
int titleTextSize;
int tickStep;

void setup()
{
  fullScreen();
  noLoop();
}

void draw()
{
  background(255, 255, 0);
  calculateResponsiveSizes();
  drawGrid();
  drawAxes();
  drawMeasurements();
}

void calculateResponsiveSizes()
{
  // Use the shorter edge so the layout works in portrait and landscape.
  // 600 is the reference size used by the original sketch.
  shortEdge = Math.min(width, height);
  layoutScale = shortEdge / 600.0;

  margin = Math.max(8, shortEdge * 0.04);
  arrowHeadSize = Math.max(4, 15 * layoutScale);
  labelTextSize = Math.max(7, Math.round(25 * layoutScale));
  titleTextSize = fitTextSize(
    "Take note of maxX and maxY",
    Math.max(10, Math.round(60 * layoutScale)),
    width - (margin * 2),
    8
  );

  // Keep ticks readable on tiny screens instead of drawing them too densely.
  tickStep = Math.max(25, Math.round(50 * layoutScale));
}

void drawGrid()
{
  float gridStep = Math.max(5, 5 * layoutScale);

  strokeWeight(Math.max(1, layoutScale));
  stroke(200);

  for (float x = 0; x < width; x += gridStep)
  {
    line(x, 0, x, height);
  }

  for (float y = 0; y < height; y += gridStep)
  {
    line(0, y, width, y);
  }
}

void drawAxes()
{
  stroke(0);
  strokeWeight(Math.max(2, 2 * layoutScale));
  fill(0);

  arrow(width - margin, 0, width, 0);
  arrow(0, height - margin, 0, height);

  textSize(labelTextSize);
  textAlign(LEFT, TOP);
  text("O", margin * 0.5, margin * 0.5);

  int majorTickStep = tickStep * 2;
  float tickLength = Math.max(4, 10 * layoutScale);
  int tickLabelSize = Math.max(6, Math.round(labelTextSize * 0.72));

  for (int x = tickStep; x < width - margin; x += tickStep)
  {
    line(x, 0, x, tickLength);
    if (x % majorTickStep == 0)
    {
      textSize(tickLabelSize);
      textAlign(CENTER, TOP);
      text(x, x, tickLength + Math.max(1, 3 * layoutScale));
    }
  }

  for (int y = tickStep; y < height - margin; y += tickStep)
  {
    line(0, y, tickLength, y);
    if (y % majorTickStep == 0)
    {
      textSize(tickLabelSize);
      textAlign(LEFT, CENTER);
      text(y, tickLength + Math.max(2, 4 * layoutScale), y);
    }
  }

  strokeWeight(Math.max(3, 3 * layoutScale));
  line(0, 0, width, 0);
  line(0, 0, 0, height);
}

void drawMeasurements()
{
  float measurementStroke = Math.max(2, 6 * layoutScale);
  float horizontalY = Math.max(margin * 2, labelTextSize * 2);
  float verticalX = margin * 2;

  stroke(0);
  fill(0);
  strokeWeight(measurementStroke);

  arrow(margin * 2, horizontalY, width - (margin * 2), horizontalY);
  arrow(
    verticalX,
    horizontalY,
    verticalX,
    height - (margin * 2)
  );

  textSize(labelTextSize);
  textAlign(CENTER, TOP);
  text("maxX = " + width, width * 0.5, horizontalY + labelTextSize * 0.45);

  textAlign(CENTER, TOP);
  textSize(titleTextSize);
  text("Take note of maxX and maxY", width * 0.5, height * 0.47);

  textSize(labelTextSize);
  text(
    "(maxX, maxY) = (" + width + ", " + height + ")",
    width * 0.5,
    height * 0.58
  );
  text("maxY = " + height, width * 0.5, height * 0.86);
}

int fitTextSize(String value, int preferredSize, float availableWidth, int minimumSize)
{
  int fittedSize = preferredSize;
  textSize(fittedSize);

  while (textWidth(value) > availableWidth && fittedSize > minimumSize)
  {
    fittedSize -= 1;
    textSize(fittedSize);
  }

  return fittedSize;
}

void arrow(float x1, float y1, float x2, float y2)
{
  line(x1, y1, x2, y2);
  pushMatrix();
  translate(x2, y2);
  float angle = atan2(x1 - x2, y2 - y1);
  rotate(angle);
  line(0, 0, -arrowHeadSize, -arrowHeadSize);
  line(0, 0, arrowHeadSize, -arrowHeadSize);
  popMatrix();
}
