extensions[ bitmap rnd]
breed[people person]
; CHECK FOR SOCIAL FORCES MODELS
;person class

globals [
  alarm?
  people_left
  time_of_evacuation
  max_people_on_patch
  max_people_on_patch_exit
  injury_levels_histogram

  S_gate
  SW_gate
  SE_gate
  N_gate
  NW_gate
  NE_gate

  ;keep track of number of injured and what type of injury
  il0
  il1
  il2
  il3
  il4
  il5
]


people-own[
  speed
  destination
  health_state
  injury_level
  evac_time
  direction_to_go
  rational ;T/F default true is rational decision
  panic            ;T/F
  panic_percentage ;range (0,1]
  aware            ;T/F
  evacuated        ;T/F
  escaping         ;T/F
  dead             ;T/F
  age              ;C = child / A = adult / E = elderly
  gender           ;M = male / F = female
]

;square meter class
patches-own[
  num_people
  ifdoor
]

;import map image from file
to import_map

  ca

  let image-file user-file

  let image bitmap:import image-file

  let height bitmap:height image

  let width bitmap:width image

  ;type "height: " print height

  ;type "width: " print width

  resize-world 0 width - 1 0 height - 1

  set-patch-size 1

  set image bitmap:to-grayscale image

  ;bitmap:copy-to-pcolors image False

  import-pcolors-rgb image-file

end

;draw map manually
;GREEN - gate
;BLACK - wall
;BLUE - outside
;WHITE - inside
;GREY - obstacle
to draw_map_SC

  ;gates
  set N_gate no-patches
  set S_gate no-patches
  set SE_gate no-patches
  set SW_gate no-patches
  set NE_gate no-patches
  set NW_gate no-patches

  ;resize map
  resize-world -50 * scale 50 * scale -100 * scale 100 * scale
  ask patches[
    set pcolor white
    ;paint rectangle
    if ((abs pycor / scale >= 84) and (abs pycor / scale <= 84 + wall-thickness) and (pxcor / scale <= 39) and (pxcor / scale >= -39)) or
       ((abs pxcor / scale >= 38) and (abs pxcor / scale <= 38 + wall-thickness) and (pycor / scale <= 84) and (pycor / scale >= -84)) [
      set pcolor black
    ]

    ;paint exits
    ;S EXIT
    if ((pycor / scale <= -84) and (pycor / scale >= -84 - wall-thickness) and (pxcor / scale <= 5.4) and (pxcor / scale >= -5.4)) [
      set pcolor green
      set S_gate (patch-set S_gate self)
    ]
    ;N EXIT
    if ((pycor / scale >= 84) and (pycor / scale <= 84 + wall-thickness) and (pxcor / scale <= 6.1) and (pxcor / scale >= -6.1)) and (not real_exits)[
      set pcolor green
      set N_gate (patch-set N_gate self)
    ]
    ;SE EXIT
    if ((pxcor / scale >= 38) and (pxcor / scale <= 38 + wall-thickness) and (pycor / scale > -84) and (pycor / scale <= -73)) [
      set pcolor green
      set SE_gate (patch-set SE_gate self)
    ]
    ;SW EXIT
    if ((pxcor / scale <= -38) and (pxcor / scale >= -38 - wall-thickness) and (pycor / scale > -84) and (pycor / scale <= -73)) [
      set pcolor green
      set SW_gate (patch-set SW_gate self)
    ]
    ;NE EXITS
    if ((pxcor / scale >= 38) and (pxcor / scale <= 38 + wall-thickness) and (pycor / scale >= 73) and (pycor / scale < 84)) [
      set pcolor green
      set NE_gate (patch-set NE_gate self)
    ]
    ;NW EXITS
    if ((pxcor / scale <= -38) and (pxcor / scale >= -38 - wall-thickness) and (pycor / scale >= 73) and (pycor / scale < 84)) [
      set pcolor green
      set NW_gate (patch-set NW_gate self)
    ]
    ;statue
    if (abs pycor / scale <= 6.25) and (abs pxcor / scale <= 5) [ set pcolor gray ]

    ;outside
    if (abs pycor / scale > 84 + wall-thickness) or (abs pxcor / scale > 38 + wall-thickness) [ set pcolor blue ]
  ]
end

;spawn people in the area equals to glob var population
to setup
  clear-all
  reset-ticks
  random-seed 42
  ;draw map
  draw_map_SC
  ;spawn people
  create-people population [
    set color rgb 0 255 0
    set shape "person"
    set size people_dim
    set speed 1
    set rational true;
    set panic false
    set panic_percentage 0;
    set aware false
    set escaping false
    set evacuated false
    set dead false
    set health_state 100
    set gender "M"
    set age "A"
    move-to one-of patches with [pcolor = white]
  ]

  set il0 0
  set il1 0
  set il2 0
  set il3 0
  set il4 0
  set il5 0
  set injury_levels_histogram []
  set alarm? false
  set max_people_on_patch 10
  ifelse real_exits[set max_people_on_patch_exit max_people_on_patch][set max_people_on_patch_exit 2]
  set time_of_evacuation 0
  ask n-of (round aware_fraction / 100 * population) people [set aware true]
  ask n-of (round panic_fraction / 100 * population) people [set panic true]
  ask n-of (round female_fraction / 100 * population) people [set gender "F"]
  ask n-of (round children_fraction / 100 * population) people [set age "C"]
  ask n-of (round elderly_fraction / 100 * population) people [set age "E"]
  ask people with [panic = true] [set panic_percentage random-float 0.75]; setting value in range (0,0.6) if panic is present

end

;start people random movement
to start_simulation
  ;print evacuation_speed
  if (alarm? = false)
  [
    ask people [
      let items ["left" "right"]
      let probabilities [0.5 0.5]
      let pairs (map list items probabilities)
      set direction_to_go first rnd:weighted-one-of-list pairs last
      ifelse (direction_to_go = "right")
      [right random 45]
      [left random 45]
      if [pcolor] of patch-ahead 1 = white [forward 1]
    ]
  ]

  ;check if evacuation should end
  if ((count people) = (count people with [dead]) and alarm? = true) [set alarm? false stop]

  ;movement
  ask people with [escaping = true and health_state > 0 and panic = false]
  [
    update_people_status
    if not dead [
      move_forward
    ]
  ]
  ask people with [escaping = true and health_state > 0 and panic = true][
    update_people_status
    if not dead [
      let items [false true]
      let p panic_percentage
      let probabilities list (p) (1 - p)
      let pairs (map list items probabilities)
      set rational first rnd:weighted-one-of-list pairs last
      ;if rational is true proceed as usual otherwise follow the crowd
      ifelse (rational = true)
        [move_forward
      set panic false]
        [follow_crowd]
    ]
  ]

  ;update time of evacuation
  if alarm? [set time_of_evacuation time_of_evacuation + 1]

  ;update patch attributes
  ask patches [set num_people count people-here with [not dead]]
  set people_left count people
  tick
end

;set alarm true and people destination
to start_evacuation
set alarm? true
;start timer to measure evacuation time(s)
reset-timer
ask people[
    set escaping true
    ;ifelse (panic = false)[
      ifelse(aware = true)
        [set destination one-of get_patch_set min-one-of patches with [pcolor = green] [distance myself]]
        [set destination one-of patches with [pcolor = green]]
      face destination]
    ;[face max-one-of neighbors [num_people] ]; if panic is present people will face the neihbors with most people in
  ;]
end

to-report get_patch_set[p]
  (
    ifelse member? p NE_gate [report NE_gate]
           member? p NW_gate [report NW_gate]
           member? p SW_gate [report SW_gate]
           member? p SE_gate [report SE_gate]
           member? p S_gate [report S_gate]
           member? p N_gate [report N_gate]
  )
end

;move input person towards his/her dest
;DO NOT CALL THIS PROCEDURE DIRECTLY, USE MOVE_FORWARD
to move_person
  ;if subject evacuated, remove it from the simulation
  if evacuated [update_injury_output die]

  ;if near an exit
  if any? neighbors with [(pcolor = green)]
  [
    ;if the gate patch is not overcrowded got there
    (ifelse any? neighbors with [(pcolor = green) and num_people < max_people_on_patch_exit]
       [
        face min-one-of neighbors with [(pcolor = green) and num_people < max_people_on_patch_exit][distance myself]
        forward 1
        set evacuated true
       ]
       ;otherwise go to the nearest gate patch that is not overcrowded
       [
        set destination min-one-of patches with [pcolor = green and num_people < max_people_on_patch_exit] [distance myself]
        face destination
       ]
    )
  ]

  ;if exiting
  (ifelse
    ;if the next patch is accessible go there
    [pcolor = white and num_people < max_people_on_patch] of patch-ahead 1 [forward 1]

    ;if next patch is overcrowded go the the nearest one that is not
    [pcolor = white and num_people >= max_people_on_patch] of patch-ahead 1
    [
        ;face min-one-of neighbors with [(pcolor = white) and num_people < max_people_on_patch][distance [destination] of myself]
        face min-one-of neighbors with [(pcolor = white)][distance [destination] of myself]
        forward 1
        face destination
    ]

    ;if next patch is exit and accessible go there
    [pcolor = green and num_people < max_people_on_patch_exit] of patch-ahead 1  [
      forward 1
      set evacuated true
      set evac_time timer
    ]

    ;if next patch is exit and overcrowded change destination to one not overcrowded
    [pcolor = green and num_people >= max_people_on_patch_exit] of patch-ahead 1
    [
     set destination min-one-of patches with [pcolor = green and num_people < max_people_on_patch_exit] [distance myself]
     if any? neighbors with [(pcolor = white) and num_people < max_people_on_patch]
      [
        face min-one-of neighbors with [(pcolor = white) and num_people < max_people_on_patch][distance [destination] of myself]
        forward 1
        face destination
      ]
    ]

    ;if next patch is a wall
    [pcolor] of patch-ahead 1 = black
    [
      ;if an exit nearby go there
      (ifelse any? neighbors with [(pcolor = green) and num_people < max_people_on_patch_exit]
      [
        face min-one-of neighbors with [pcolor = green] [distance [destination] of myself]
        forward 1
        set evacuated true
        set evac_time timer
      ]

      ;if a free patch nearby go there
      any? neighbors with [(pcolor = white) and num_people < max_people_on_patch]
      [
        face min-one-of neighbors with [pcolor = white] [distance [destination] of myself]
        forward 1
        face destination
      ]

      ;change destination patch
      [set destination min-one-of patches with [pcolor = green and num_people < max_people_on_patch_exit][distance [destination] of myself]]
      )
    ]

    ;if next patch is obstacle change destination gate
    [pcolor = gray] of patch-ahead 1
     [
      set destination one-of (patches with [pcolor = green])
      face destination
      if  [(pcolor = white) and num_people < max_people_on_patch] of patch-ahead 1 [forward 1]
     ]

  )
end

;update health, evacuated, speed
to update_people_status
   ; get number of people on patch
   let n count (turtles-on patch-here) with [not dead]

   set health_state update_hs n
   if health_state < 0 [set health_state 0]
   ;get injury level and set color accordingly
   update_injury_level
   (
     ifelse injury_level = 6 [set dead true set color rgb 255 0 0
                              set injury_levels_histogram fput injury_level injury_levels_histogram]  ;fatal
            injury_level = 5 [set color rgb 255 102 0]              ;critical
            injury_level = 4 [set color rgb 255 204 0]              ;severe
            injury_level = 3 [set color rgb 0 153 255]              ;serious
            injury_level = 2 [set color rgb 0 255 255]              ;moderate
            injury_level = 1 [set color rgb 153 255 102]            ;minor
            injury_level = 0 [set color rgb 0 255 0]                ;healthy
   )
  update_speed
end

; return the level of injury based on the health state (https://en.wikipedia.org/wiki/Abbreviated_Injury_Scale)
to update_injury_level
  set injury_level max list (6 - (floor (health_state / 15))) 0
end

; update health state - a possible implementation
; descrease value by percentage value based on n (number of people in same patch)
to-report update_hs [n]
  ;report health_state - (health_state * (n - 1) / 100)
  ; if elder the injury is twice as bad, if children thrice
  (
    ifelse age = "A" [report health_state - ((n - 1) * injury_weight)]
           age = "E" [report health_state - ((n - 1) * injury_weight * 2)]
           age = "C" [report health_state - ((n - 1) * injury_weight * 3)]
  )

end

; update speed based on injury level (TODO also on gender/age)
to update_speed
  (
   ifelse injury_level = 6 [set speed 0]    ;fatal
          injury_level = 5 [set speed 1]    ;critical
          injury_level = 4 [set speed 2]    ;severe
          injury_level = 3 [set speed 3]    ;serious
          injury_level = 2 [set speed 4]    ;moderate
          injury_level = 1 [set speed 5]    ;minor
          injury_level = 0 [set speed 5]    ;healthy
  )
  (
    ifelse age = "E" [set speed speed - 3]
           age = "C" [set speed speed - 2]
  )
  if gender = "F" [set speed speed - 1]

  if (speed <= 0) and (injury_level < 6)[set speed 1]
  if (speed < 0) and (injury_level = 6)[set speed 0]
end


; move person forward of speed patches if possible, if there is a wall or an obstacle stop
to move_forward
  if not speed_enabled [set speed 1]
  let slip false
  if glass_bottles [set slip get_slip]
  ; if slipping decrease health_state by 5%
  if slip [set health_state health_state - (health_state / 20)]
  let i 1
  update_people_status
  while[(i <= speed) and (not slip) and (not dead)]
  [
    move_person
    set i i + 1
  ]
end

; update globals used to plot histogram of injury levels
to update_injury_output
  (
   ifelse injury_level = 5 [set il5 il5 + 1]    ;critical
          injury_level = 4 [set il4 il4 + 1]    ;severe
          injury_level = 3 [set il3 il3 + 1]    ;serious
          injury_level = 2 [set il2 il2 + 1]    ;moderate
          injury_level = 1 [set il1 il1 + 1]    ;minor
          injury_level = 0 [set il0 il0 + 1]    ;healthy
  )
  set injury_levels_histogram fput injury_level injury_levels_histogram
end

;if people are with decision_to_take false ( i.e. not rational decision) they will tend to follow other people instead of looking for an exit
to follow_crowd
  update_people_status
  if evacuated [update_injury_output die]
  ;the following block is the same as move_person, based on the assumption that if an exit is close, rationality overcome panic
  ;if near an exit
  ifelse  any? neighbors with [(pcolor = green)]
  [
    ;if the gate patch is not overcrowded got there
    (ifelse any? neighbors with [(pcolor = green) and num_people < max_people_on_patch_exit]
       [
        face min-one-of neighbors with [(pcolor = green) and num_people < max_people_on_patch_exit][distance myself]
        forward 1
        set evacuated true
       ]
       ;otherwise go to the nearest gate patch that is not overcrowded
       [
        set destination min-one-of patches with [pcolor = green and num_people < max_people_on_patch_exit] [distance myself]
        face destination
       ]
    )
  ]

   [face max-one-of neighbors with [pcolor = white] [num_people]
    forward 1]
end

;slip with probability slippig_chance
to-report get_slip
  let p random 100
  ifelse p <= slipping_chance
    [report true]
    [report false]
end
@#$#@#$#@
GRAPHICS-WINDOW
380
10
589
420
-1
-1
1.0
1
10
1
1
1
0
0
0
1
-100
100
-200
200
0
0
1
ticks
30.0

INPUTBOX
0
373
104
433
scale
2.0
1
0
Number

INPUTBOX
216
372
319
432
wall-thickness
0.0
1
0
Number

INPUTBOX
170
10
275
70
population
30000.0
1
0
Number

BUTTON
0
10
81
57
SETUP
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
0
62
165
95
START SIMULATION
start_simulation
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
85
10
166
57
ALARM
start_evacuation
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
0
98
172
131
aware_fraction
aware_fraction
0
100
50.0
1
1
NIL
HORIZONTAL

MONITOR
760
10
823
55
Evacuated
population - count people
17
1
11

PLOT
842
157
1249
301
Evacuation Speed
time
NIL
0.0
10.0
0.0
5.0
true
false
"" ""
PENS
"evacuation speed" 1.0 0 -13840069 true "" "if alarm? = true [plot count people with [evacuated]]"

PLOT
841
10
1250
154
Injury Levels
NIL
NIL
0.0
10.0
0.0
1.1
true
true
"" ""
PENS
"minor" 1.0 0 -5509967 true "" "if (alarm? = true) and (people_left > 0) [plot il1]"
"moderate" 1.0 0 -11221820 true "" "if (alarm? = true) and (people_left > 0) [plot il2]"
"serious" 1.0 0 -14454117 true "" "if (alarm? = true) and (people_left > 0) [plot il3]"
"severe" 1.0 0 -1184463 true "" "if (alarm? = true) and (people_left > 0) [plot il4]"
"critical" 1.0 0 -955883 true "" "if (alarm? = true) and (people_left > 0) [plot il5]"
"fatal" 1.0 0 -2674135 true "" "if (alarm? = true) and (people_left > 0) [plot count people with [dead]]"
"healthy" 1.0 0 -11085214 true "" "if (alarm? = true) and (people_left > 0) [plot il0]"

SLIDER
0
133
172
166
panic_fraction
panic_fraction
0
100
10.0
1
1
NIL
HORIZONTAL

INPUTBOX
106
373
212
433
people_dim
0.75
1
0
Number

PLOT
842
305
1249
450
Evacuation Time
time
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"evacuation time" 1.0 0 -8630108 true "" "let evac_people people with [evacuated]\nif any? evac_people[\n   let m mean [evac_time] of evac_people\n   if m > 0 [plot m]\n]"

SWITCH
112
298
239
331
speed_enabled
speed_enabled
0
1
-1000

MONITOR
716
110
776
155
Fatal
count people with [dead]
17
1
11

INPUTBOX
0
297
105
365
injury_weight
0.1365
1
0
Number

SWITCH
188
133
315
166
real_exits
real_exits
0
1
-1000

MONITOR
657
66
716
111
Minor
il1
17
1
11

MONITOR
716
66
775
111
Moderate
il2
17
1
11

MONITOR
775
66
834
111
Serious
il3
17
1
11

MONITOR
598
110
657
155
Severe
il4
17
1
11

MONITOR
657
110
716
155
Critical
il5
17
1
11

MONITOR
598
66
657
111
Healthy
il0
17
1
11

SWITCH
188
98
314
131
glass_bottles
glass_bottles
1
1
-1000

SLIDER
113
333
239
366
slipping_chance
slipping_chance
0
100
1.0
1
1
NIL
HORIZONTAL

MONITOR
634
10
738
55
Evacuation time
time_of_evacuation
17
1
11

SLIDER
0
177
126
210
female_fraction
female_fraction
0
100
50.0
1
1
NIL
HORIZONTAL

SLIDER
136
177
262
210
elderly_fraction
elderly_fraction
0
100 - adult_fraction
10.0
1
1
NIL
HORIZONTAL

SLIDER
136
210
262
243
children_fraction
children_fraction
0
100 - adult_fraction - elderly_fraction
10.0
1
1
NIL
HORIZONTAL

SLIDER
0
210
126
243
adult_fraction
adult_fraction
0
100
80.0
1
1
NIL
HORIZONTAL

PLOT
594
214
837
360
Average Speed
time
m/s
0.0
10.0
0.0
5.0
true
false
"" ""
PENS
"default" 1.0 0 -14835848 true "" " if (count people > 0) and (alarm? = true) [plot mean [speed] of people]"

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="descriptive" repetitions="10" runMetricsEveryStep="false">
    <setup>setup
start_evacuation</setup>
    <go>start_simulation</go>
    <final>export-plot "Evacuation Speed" (word "C:/Users/dadpl/git/CrowdLogo/results/descriptive/evacuation_speed/evacuation_speed_run_" behaviorspace-run-number ".csv")
export-plot "Evacuation Time" (word "C:/Users/dadpl/git/CrowdLogo/results/descriptive/evacuation_time/evacuation_time_run_" behaviorspace-run-number ".csv")
export-plot "Average Speed" (word "C:/Users/dadpl/git/CrowdLogo/results/descriptive/average_speed/average_speed_run_" behaviorspace-run-number ".csv")</final>
    <metric>il0</metric>
    <metric>il1</metric>
    <metric>il2</metric>
    <metric>il3</metric>
    <metric>il4</metric>
    <metric>il5</metric>
    <metric>count people with [dead]</metric>
    <enumeratedValueSet variable="scale">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="glass_bottles">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult_fraction">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="30000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="elderly_fraction">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="slipping_chance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_dim">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wall-thickness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed_enabled">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="panic_fraction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aware_fraction">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female_fraction">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="children_fraction">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="real_exits">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="injury_weight">
      <value value="0.1365"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="speculative_num_people" repetitions="1" runMetricsEveryStep="false">
    <setup>setup
start_evacuation</setup>
    <go>start_simulation</go>
    <final>export-plot "Evacuation Speed" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/number_of_people/evacuation_speed/evacuation_speed_run_" behaviorspace-run-number ".csv")
export-plot "Evacuation Time" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/number_of_people/evacuation_time/evacuation_time_run_" behaviorspace-run-number ".csv")
export-plot "Average Speed" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/number_of_people/average_speed/average_speed_run_" behaviorspace-run-number ".csv")</final>
    <metric>il0</metric>
    <metric>il1</metric>
    <metric>il2</metric>
    <metric>il3</metric>
    <metric>il4</metric>
    <metric>il5</metric>
    <metric>count people with [dead]</metric>
    <enumeratedValueSet variable="scale">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="glass_bottles">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult_fraction">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="30000"/>
      <value value="27500"/>
      <value value="25000"/>
      <value value="22500"/>
      <value value="20000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="elderly_fraction">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="slipping_chance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_dim">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wall-thickness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed_enabled">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="panic_fraction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aware_fraction">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female_fraction">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="children_fraction">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="real_exits">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="injury_weight">
      <value value="0.1365"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="speculative_aware_fraction" repetitions="1" runMetricsEveryStep="false">
    <setup>setup
start_evacuation</setup>
    <go>start_simulation</go>
    <final>export-plot "Evacuation Speed" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/aware_fraction/evacuation_speed/evacuation_speed_run_" behaviorspace-run-number ".csv")
export-plot "Evacuation Time" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/aware_fraction/evacuation_time/evacuation_time_run_" behaviorspace-run-number ".csv")
export-plot "Average Speed" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/aware_fraction/average_speed/average_speed_run_" behaviorspace-run-number ".csv")</final>
    <metric>il0</metric>
    <metric>il1</metric>
    <metric>il2</metric>
    <metric>il3</metric>
    <metric>il4</metric>
    <metric>il5</metric>
    <metric>count people with [dead]</metric>
    <enumeratedValueSet variable="scale">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="glass_bottles">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult_fraction">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="30000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="elderly_fraction">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="slipping_chance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_dim">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wall-thickness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed_enabled">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="panic_fraction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aware_fraction">
      <value value="50"/>
      <value value="60"/>
      <value value="70"/>
      <value value="80"/>
      <value value="90"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female_fraction">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="children_fraction">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="real_exits">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="injury_weight">
      <value value="0.1365"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="speculative_accessible_exits" repetitions="3" runMetricsEveryStep="false">
    <setup>setup
start_evacuation</setup>
    <go>start_simulation</go>
    <final>export-plot "Evacuation Speed" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/accessible_exits/evacuation_speed/evacuation_speed_run_" behaviorspace-run-number ".csv")
export-plot "Evacuation Time" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/accessible_exits/evacuation_time/evacuation_time_run_" behaviorspace-run-number ".csv")
export-plot "Average Speed" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/accessible_exits/average_speed/average_speed_run_" behaviorspace-run-number ".csv")</final>
    <metric>il0</metric>
    <metric>il1</metric>
    <metric>il2</metric>
    <metric>il3</metric>
    <metric>il4</metric>
    <metric>il5</metric>
    <metric>count people with [dead]</metric>
    <enumeratedValueSet variable="scale">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="glass_bottles">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult_fraction">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="30000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="elderly_fraction">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="slipping_chance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_dim">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wall-thickness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed_enabled">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="panic_fraction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aware_fraction">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female_fraction">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="children_fraction">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="real_exits">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="injury_weight">
      <value value="0.1365"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="speculative_glass_bottles" repetitions="3" runMetricsEveryStep="false">
    <setup>setup
start_evacuation</setup>
    <go>start_simulation</go>
    <final>export-plot "Evacuation Speed" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/glass_bottles/evacuation_speed/evacuation_speed_run_" behaviorspace-run-number ".csv")
export-plot "Evacuation Time" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/glass_bottles/evacuation_time/evacuation_time_run_" behaviorspace-run-number ".csv")
export-plot "Average Speed" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/glass_bottles/average_speed/average_speed_run_" behaviorspace-run-number ".csv")</final>
    <metric>il0</metric>
    <metric>il1</metric>
    <metric>il2</metric>
    <metric>il3</metric>
    <metric>il4</metric>
    <metric>il5</metric>
    <metric>count people with [dead]</metric>
    <enumeratedValueSet variable="scale">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="glass_bottles">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult_fraction">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="30000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="elderly_fraction">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="slipping_chance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_dim">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wall-thickness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed_enabled">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="panic_fraction">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aware_fraction">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female_fraction">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="children_fraction">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="real_exits">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="injury_weight">
      <value value="0.1365"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="speculative_panic_fraction" repetitions="1" runMetricsEveryStep="false">
    <setup>setup
start_evacuation</setup>
    <go>start_simulation</go>
    <final>export-plot "Evacuation Speed" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/panic_fraction/evacuation_speed/evacuation_speed_run_" behaviorspace-run-number ".csv")
export-plot "Evacuation Time" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/panic_fraction/evacuation_time/evacuation_time_run_" behaviorspace-run-number ".csv")
export-plot "Average Speed" (word "C:/Users/dadpl/git/CrowdLogo/results/speculative/panic_fraction/average_speed/average_speed_run_" behaviorspace-run-number ".csv")</final>
    <metric>il0</metric>
    <metric>il1</metric>
    <metric>il2</metric>
    <metric>il3</metric>
    <metric>il4</metric>
    <metric>il5</metric>
    <metric>count people with [dead]</metric>
    <enumeratedValueSet variable="scale">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="glass_bottles">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="adult_fraction">
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population">
      <value value="30000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="elderly_fraction">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="slipping_chance">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="people_dim">
      <value value="0.75"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="wall-thickness">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="speed_enabled">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="panic_fraction">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aware_fraction">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="female_fraction">
      <value value="50"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="children_fraction">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="real_exits">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="injury_weight">
      <value value="0.1365"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
