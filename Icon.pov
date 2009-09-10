global_settings { assumed_gamma 2.2 }

#declare BOARD_WIDTH = 480;
#declare BOARD_HEIGHT = 320;
#declare BORDER_WIDTH = 10;
#declare BORDER_HEIGHT = 5;
#declare POINT_WIDTH = 32;
#declare POINT_HEIGHT = 120;
#declare BAR_WIDTH = 36;
#declare BAR_OFFSET = 50;
#declare BEAROFF_X = (2*BORDER_WIDTH+BAR_WIDTH+12*POINT_WIDTH);
#declare CHEQUER_HEIGHT = 28;
#declare CHEQUER_RADIUS = 14;
#declare DICE_SIZE = 32;

camera {  // orthographic
   location  <75, 170, -45>
   look_at   <87, 0, 80>  
   up <0, 1, 0>
   right<1, 0, 0>
   angle 40  
}                       

                    
light_source { <120, 580, 160> color red .9 green .9 blue .9 shadowless }
light_source { <120, 0, -160> color red 1 green 1 blue .9 shadowless  }

box { <0, -10, 0>, <12*POINT_WIDTH+2*BORDER_WIDTH+BAR_WIDTH,10,BORDER_HEIGHT>
    finish {
       ambient 0.2
       diffuse 0.8
    }
    pigment { color red 0.5 green 0.25 blue 0 }
}

box { <0, -10, 0>, <BORDER_WIDTH,10,BOARD_HEIGHT>
    finish {
       ambient 0.2
       diffuse 0.8
    }
    pigment { color red 0.5 green 0.25 blue 0 }
}

box { <12*POINT_WIDTH+BORDER_WIDTH+BAR_WIDTH, -10, 0>, <12*POINT_WIDTH+2*BORDER_WIDTH+BAR_WIDTH,10,BOARD_HEIGHT>
    finish {
       ambient 0.2
       diffuse 0.8
    }
    pigment { color red 0.5 green 0.25 blue 0 }
}

box { <0, -10, BOARD_HEIGHT-BORDER_HEIGHT>, <12*POINT_WIDTH+2*BORDER_WIDTH+BAR_WIDTH,10,BOARD_HEIGHT>
    finish {
       ambient 0.2
       diffuse 0.8
    }
    pigment { color red 0.5 green 0.25 blue 0 }
}

box { <6*POINT_WIDTH+BORDER_WIDTH, -10, 0>, <6*POINT_WIDTH+BORDER_WIDTH+BAR_WIDTH,10,BOARD_HEIGHT>
    finish {
       ambient 0.2
       diffuse 0.8
    }
    pigment { color red 0.5 green 0.25 blue 0 }
}

box { <BORDER_WIDTH,-10,BORDER_HEIGHT>, <BORDER_WIDTH+6*POINT_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT>
    finish {
       ambient 0.2
       diffuse 0.8
    }
    pigment { color red 0 green 0.5 blue 0 }
}

box { <BORDER_WIDTH+6*POINT_WIDTH+BAR_WIDTH,-10,BORDER_HEIGHT>, <BORDER_WIDTH+12*POINT_WIDTH+BAR_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT>
    finish {
       ambient 0.2
       diffuse 0.8
    }
    pigment { color red 0 green 0.5 blue 0 }
}                          

#declare PointTri =
union {
        triangle { <0,0,0>,<POINT_WIDTH/2,0,POINT_HEIGHT>,<POINT_WIDTH,0,0>
            finish {
               ambient 0.2
               diffuse 0.7
            }
            pigment { color red 1 green 0.75 blue 0.25 }
        }
        triangle { <POINT_WIDTH,0,0>,<POINT_WIDTH+POINT_WIDTH/2,0,POINT_HEIGHT>,<2*POINT_WIDTH,0,0>
            finish {
               ambient 0.2
               diffuse 0.7
            }
            pigment { color red 0.75 green 0.25 blue 0 }
        }
}

object {
    PointTri
    translate <BORDER_WIDTH,0,BORDER_HEIGHT>
}

object {
    PointTri
    translate <BORDER_WIDTH+2*POINT_WIDTH,0,BORDER_HEIGHT>
}

object {
    PointTri
    translate <BORDER_WIDTH+4*POINT_WIDTH,0,BORDER_HEIGHT>
}

object {
    PointTri
    translate <BORDER_WIDTH+BAR_WIDTH+6*POINT_WIDTH,0,BORDER_HEIGHT>
}

object {
    PointTri
    translate <BORDER_WIDTH+BAR_WIDTH+8*POINT_WIDTH,0,BORDER_HEIGHT>
}

object {
    PointTri
    translate <BORDER_WIDTH+BAR_WIDTH+10*POINT_WIDTH,0,BORDER_HEIGHT>
}

object {
    PointTri
    rotate <0,180,0>
    translate <BORDER_WIDTH+2*POINT_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT>
}

object {
    PointTri
    rotate <0,180,0>
    translate <BORDER_WIDTH+4*POINT_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT>
}

object {
    PointTri
    rotate <0,180,0>
    translate <BORDER_WIDTH+6*POINT_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT>
}

object {
    PointTri
    rotate <0,180,0>
    translate <BORDER_WIDTH+BAR_WIDTH+8*POINT_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT>
}

object {
    PointTri
    rotate <0,180,0>
    translate <BORDER_WIDTH+BAR_WIDTH+10*POINT_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT>
}

object {
    PointTri
    rotate <0,180,0>
    translate <BORDER_WIDTH+BAR_WIDTH+12*POINT_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT>
}

#declare WhiteChecker =
cylinder { <POINT_WIDTH/2, -10, CHEQUER_RADIUS>, <POINT_WIDTH/2, 5,  CHEQUER_RADIUS>, CHEQUER_RADIUS
    finish {
        ambient 0.2
        diffuse 0.8
    }
    pigment { color red 0.2 green 0.2 blue 0.2 }
}

#declare BlackChecker =
cylinder { <POINT_WIDTH/2, -10, CHEQUER_RADIUS>, <POINT_WIDTH/2, 5,  CHEQUER_RADIUS>, CHEQUER_RADIUS
    finish {
        ambient 0.2
        diffuse 0.8
    }
    pigment { color red 0.95 green 0.95 blue 0.95 }
}

object {
    WhiteChecker
    translate <BORDER_WIDTH,0,BORDER_HEIGHT>
}

object {
    WhiteChecker
    translate <BORDER_WIDTH,0,BORDER_HEIGHT+CHEQUER_HEIGHT>
}

object {
    WhiteChecker
    translate <BORDER_WIDTH,0,BORDER_HEIGHT+2*CHEQUER_HEIGHT>
}

object {
    WhiteChecker
    translate <BORDER_WIDTH,0,BORDER_HEIGHT+3*CHEQUER_HEIGHT>
}

object {
    WhiteChecker
    translate <BORDER_WIDTH,0,BORDER_HEIGHT+4*CHEQUER_HEIGHT>
}

object {
    BlackChecker
    translate <BORDER_WIDTH+4*POINT_WIDTH,0,BORDER_HEIGHT>
}

object {
    BlackChecker
    translate <BORDER_WIDTH+4*POINT_WIDTH,0,BORDER_HEIGHT+CHEQUER_HEIGHT>
}

object {
    BlackChecker
    translate <BORDER_WIDTH+4*POINT_WIDTH,0,BORDER_HEIGHT+2*CHEQUER_HEIGHT>
}

object {
    BlackChecker
    translate <BORDER_WIDTH+6*POINT_WIDTH+BAR_WIDTH,0,BORDER_HEIGHT>
}

object {
    BlackChecker
    translate <BORDER_WIDTH+6*POINT_WIDTH+BAR_WIDTH,0,BORDER_HEIGHT+CHEQUER_HEIGHT>
}

object {
    BlackChecker
    translate <BORDER_WIDTH+6*POINT_WIDTH+BAR_WIDTH,0,BORDER_HEIGHT+2*CHEQUER_HEIGHT>
}

object {
    BlackChecker
    translate <BORDER_WIDTH+6*POINT_WIDTH+BAR_WIDTH,0,BORDER_HEIGHT+3*CHEQUER_HEIGHT>
}

object {
    BlackChecker
    translate <BORDER_WIDTH+6*POINT_WIDTH+BAR_WIDTH,0,BORDER_HEIGHT+4*CHEQUER_HEIGHT>
}

object {
    WhiteChecker
    translate <BORDER_WIDTH+11*POINT_WIDTH+BAR_WIDTH,0,BORDER_HEIGHT>
}

object {
    WhiteChecker
    translate <BORDER_WIDTH+11*POINT_WIDTH+BAR_WIDTH,0,BORDER_HEIGHT+CHEQUER_HEIGHT>
}



object {
    BlackChecker
    translate <BORDER_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-CHEQUER_HEIGHT>
}

object {
    BlackChecker
    translate <BORDER_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-2*CHEQUER_HEIGHT>
}

object {
    BlackChecker
    translate <BORDER_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-3*CHEQUER_HEIGHT>
}

object {
    BlackChecker
    translate <BORDER_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-4*CHEQUER_HEIGHT>
}

object {
    BlackChecker
    translate <BORDER_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-5*CHEQUER_HEIGHT>
}   

object {
    WhiteChecker
    translate <BORDER_WIDTH+4*POINT_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-CHEQUER_HEIGHT>
}

object {
    WhiteChecker
    translate <BORDER_WIDTH+4*POINT_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-2*CHEQUER_HEIGHT>
}

object {
    WhiteChecker
    translate <BORDER_WIDTH+4*POINT_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-3*CHEQUER_HEIGHT>
}





object {
    WhiteChecker
    translate <BORDER_WIDTH+6*POINT_WIDTH+BAR_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-CHEQUER_HEIGHT>
}

object {
    WhiteChecker
    translate <BORDER_WIDTH+6*POINT_WIDTH+BAR_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-2*CHEQUER_HEIGHT>
}

object {
    WhiteChecker
    translate <BORDER_WIDTH+6*POINT_WIDTH+BAR_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-3*CHEQUER_HEIGHT>
}

object {
    WhiteChecker
    translate <BORDER_WIDTH+6*POINT_WIDTH+BAR_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-4*CHEQUER_HEIGHT>
}

object {
    WhiteChecker
    translate <BORDER_WIDTH+6*POINT_WIDTH+BAR_WIDTH,0,BOARD_HEIGHT-BORDER_HEIGHT-5*CHEQUER_HEIGHT>
}

#declare DICESIZE = 10;  
#declare DICEDIAG = 15.5;
       
#declare Dice = 
difference {
  intersection {
    box { <-DICESIZE, -DICESIZE, -DICESIZE>, <DICESIZE,DICESIZE,DICESIZE> }
    plane { <DICESIZE, DICESIZE, DICESIZE>, DICEDIAG }
    plane { <DICESIZE, DICESIZE, -DICESIZE>, DICEDIAG }
    plane { <DICESIZE, -DICESIZE, DICESIZE>, DICEDIAG }
    plane { <DICESIZE, -DICESIZE, -DICESIZE>, DICEDIAG }
    plane { <-DICESIZE, DICESIZE, DICESIZE>, DICEDIAG }
    plane { <-DICESIZE, DICESIZE, -DICESIZE>, DICEDIAG }
    plane { <-DICESIZE, -DICESIZE, DICESIZE>, DICEDIAG }
    plane { <-DICESIZE, -DICESIZE, -DICESIZE>, DICEDIAG }

    finish {
        ambient 0.2
        diffuse 0.8
    }
    pigment { color red 0.95 green 0.95 blue 0.95 }

  }         
  union {
    sphere { <0,0,-DICESIZE> 2 }
    sphere { <DICESIZE/2,DICESIZE/2,-DICESIZE> 2 }
    sphere { <DICESIZE/2,-DICESIZE/2,-DICESIZE> 2 }
    sphere { <-DICESIZE/2,DICESIZE/2,-DICESIZE> 2 }
    sphere { <-DICESIZE/2,-DICESIZE/2,-DICESIZE> 2 }

    sphere { <-DICESIZE,DICESIZE/2,-DICESIZE/2> 2 }
    sphere { <-DICESIZE,-DICESIZE/2,-DICESIZE/2> 2 }
    sphere { <-DICESIZE,DICESIZE/2,DICESIZE/2> 2 }
    sphere { <-DICESIZE,-DICESIZE/2,DICESIZE/2> 2 }

    sphere { <-DICESIZE/2,DICESIZE,-DICESIZE/2> 2 }
    sphere { <0,DICESIZE,-DICESIZE/2> 2 }
    sphere { <DICESIZE/2,DICESIZE,-DICESIZE/2> 2 }
    sphere { <-DICESIZE/2,DICESIZE,DICESIZE/2> 2 }
    sphere { <0,DICESIZE,DICESIZE/2> 2 }
    sphere { <DICESIZE/2,DICESIZE,DICESIZE/2> 2 }

    sphere { <0,-DICESIZE,0> 2 }

    sphere { <DICESIZE/2,DICESIZE/2,DICESIZE> 2 }
    sphere { <-DICESIZE/2,-DICESIZE/2,DICESIZE> 2 }

    sphere { <DICESIZE,DICESIZE/2,DICESIZE/2> 2 }
    sphere { <DICESIZE,0,0> 2 }
    sphere { <DICESIZE,-DICESIZE/2,-DICESIZE/2> 2 }
  }
}
          
          
object {
    Dice
    rotate <0,-25,0>
    translate <80, 16, 70>
}                                        

object {
    Dice
    rotate <-90,45,0>
    translate <110, 16, 110>
}                                        
