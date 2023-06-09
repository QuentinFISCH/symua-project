globals [
  p_echec
  t_min
  t_max
  pollen-decrease-rate
  flower_min_pollen
  flower_max_pollen
  INITIAL_SPEED
  POLLEN_SPEED
  birth-timer
  p_piste_danse
  p_succes
  p_mort
  p_scout
  p_sortie_impossible
]

turtles-own [
  speed ; the speed at which the bee is moving
  pollen-carried ; amount of pollen carried
  distance-to-target ; the distance between the bee and its target
  target-flower
  next-task
  wait-time
  hive
  hive-position
]

patches-own [
  flower?
  flower-pollen
  flower-initial-pollen
  flower-pollen-increase-rate
  hive?
  hive-pollen
  hive-s-impact
  hive-max-pollen
]

to setup
  clear-all

  set birth-timer 50
  set p_piste_danse 0.2
  set p_succes 0.8
  set p_mort 0.0108
  set p_scout 0.3
  set p_sortie_impossible 0.2
  set INITiAL_SPEED 2
  set POLLEN_SPEED 1

  set p_echec 1 - p_succes

  set t_min 1000
  set t_max 10000
  set pollen-decrease-rate 0.015

  setup-flowers
  setup-hives
  setup-bees

  reset-ticks
end


to setup-hives
  let color-list [ 97.9 94.5 57.5 63.8 17.6 14.9 27.5 25.1 117.9 114.4 ]

  ask patches [
    set hive? false
  ]

  let i 0
  ask n-of num-hives patches with [
    distancexy 0 0 > 5 and abs pxcor < (max-pxcor - 2) and
    abs pycor < (max-pycor - 2)
  ] [
    let center-pxcor pxcor
    let center-pycor pycor
    set hive? true
    ask patches with [(sqrt ((pxcor - center-pxcor) * (pxcor - center-pxcor) + (pycor - center-pycor) * (pycor - center-pycor))) <= 2] [
      set pcolor yellow
      set hive-pollen 0
      set flower? false
      set flower-pollen 0
      set hive-s-impact 1
      set hive-max-pollen 100000
    ]

    sprout num-bees-per-hive [
      set hive patch-here
      fd random-float 3
      set hive-position patch-here
      set heading random 360
      set size 1.5
      set speed INITIAL_SPEED
      set color gray
      set pollen-carried 0
      set next-task [ -> repos ]
    ]

    set-current-plot "pollen"
    create-temporary-plot-pen word "pollen" i
    set-plot-pen-color item i color-list
    set i i + 1
  ]
end

to setup-bees
  set-default-shape turtles "bee 2"
end


to setup-flowers
  set flower_min_pollen 10
  set flower_max_pollen 1000

  ask patches [
    set pcolor green
    set flower? false
    set flower-pollen 0
    if random-float 1 < flower-density [
      set flower? true
      set flower-pollen flower_min_pollen + random(flower_max_pollen - flower_min_pollen)
      set flower-initial-pollen flower-pollen
      set flower-pollen-increase-rate (1 + random 2)
      let t (flower-pollen / (flower_max_pollen - flower_min_pollen)) * 255
      set pcolor rgb 255 t t
    ]
  ]
end


to go
  ask turtles [
    run next-task
  ]

  decrease-nest-pollen
  increase-flower-pollen
  plot-pollen
  tick
end


to repos
  let random-proba random-float 1
  let random-proba-sortie random-float 1

  set color gray

  set target-flower 0 ; reset target flower
  if (random-proba-sortie < p_sortie_impossible) [
    set next-task [ -> repos ]
    stop
  ]

  ifelse (random-proba < p_piste_danse)[
    set next-task [ -> sur-la-piste-de-danse ]
  ] [
    set next-task [ -> repos ]
  ]

end


to sur-la-piste-de-danse
  let random-proba-sortie random-float 1
  let random-proba-scout random-float 1

  set color pink

  if (random-proba-sortie < p_sortie_impossible) [
    set next-task [ -> repos ]
    stop
  ]
  let profitabilite 0
  if target-flower != 0 [
    set profitabilite ([flower-pollen] of target-flower / flower_max_pollen)
  ]
  if (random-proba-scout < 1 - p_scout) [ ; todo: and profitabilité < s
    set next-task [ -> en-recherche-de-danse ]
    stop
  ]
  if (random-proba-scout < p_scout or profitabilite < [hive-s-impact] of hive) [
    set next-task [ -> butinage ]
    stop
  ]
  if (profitabilite >= [hive-s-impact] of hive) [
    set next-task [ -> danse ]
  ]
end


to en-recherche-de-danse
  let random-proba-sortie random-float 1
  let random-proba-scout random-float 1

  set color blue

  set target-flower 0 ; reset target flower

  if (random-proba-sortie < p_sortie_impossible) [
    set wait-time 0
    set next-task [ -> repos ]
    stop
  ]

  if (wait-time = 0) [
    set wait-time (one-of (range t_min t_max))
  ]
  if (wait-time = 1) [
    set wait-time (wait-time - 1) ; wait-time = 0
    if (random-proba-scout < p_scout) [
      set next-task [ -> butinage ]
    ]
    stop
  ]

  ; search for other bees dancing
  let recrute false
  let dancing_bee one-of (other turtles with [next-task = [ -> danse ]])
  if (dancing_bee != nobody) [
    set recrute true
  ]

  ifelse (not recrute) [
    set wait-time (wait-time - 1)
    set next-task [ -> en-recherche-de-danse ]
  ] [
    set target-flower ([target-flower] of dancing_bee)
    set wait-time 0
    set next-task [ -> butinage ]
  ]
end

to butinage
  set color yellow

  let random-proba-mort random-float 1
  if (random-proba-mort < p_mort) [
    die
    stop
  ]

  if (target-flower = 0) [
    set target-flower one-of patches in-radius scout-radius with [flower? = true]
    if (target-flower = Nobody) [
      set next-task [-> echec]
      set target-flower 0
      stop
    ]
  ]
  set distance-to-target (distance target-flower)
  ifelse (distance target-flower) < 1 [ ; bee is on the flower, get pollen and go back to nest
    let random-succes random-float 1
    ifelse random-succes < p_succes [
      set speed POLLEN_SPEED
      set next-task [ -> succes ]
    ] [
      set next-task [ -> echec ]
    ]
  ] [  ; bee is heading towards a flower without pollen
    set heading (towards target-flower)
    proceed 60
    set next-task [ -> butinage ]
  ]
end

to succes
  let random-pollen 20 + random 10
  ifelse ([flower-pollen] of target-flower) < random-pollen [
    echec
  ] [
    set color green

    set pollen-carried random-pollen
    let flower-x ([pxcor] of target-flower)
    let flower-y ([pycor] of target-flower)
    ask patches with [pxcor = flower-x and pycor = flower-y] [
      set flower-pollen (flower-pollen - random-pollen)
    ]

    go-back-to-nest
  ]
end


to echec
  set color red

  set pollen-carried 0
  go-back-to-nest
end


to danse
  let random-proba-sortie random-float 1

  set color orange

  if (random-proba-sortie < p_sortie_impossible) [
    set next-task [ -> repos ]
    stop
  ]
  set next-task [ -> butinage ]
end


to proceed [angle]
  rt (random angle - random angle)
  fd speed
end


to go-back-to-nest
  face hive-position
  set distance-to-target (distance hive-position)

  if distance hive-position < 1 [
    let hivex ([pxcor] of hive)
    let hivey ([pycor] of hive)
    let pollen-to-add pollen-carried
    ask patches with [pxcor = hivex and pycor = hivey] [
      set hive-pollen (hive-pollen + pollen-to-add)
      if hive-pollen > hive-max-pollen [
        set hive-max-pollen hive-pollen
      ]
    ]
    set pollen-carried 0
    set speed INITIAL_SPEED
    set next-task [ -> sur-la-piste-de-danse ]
    stop
  ]

  proceed 30
end


to decrease-nest-pollen
  ask patches with [hive? = true] [
    set hive-pollen round (hive-pollen - hive-pollen * pollen-decrease-rate)
    set hive-s-impact (hive-pollen / hive-max-pollen)

    set birth-timer (birth-timer - 1)
    if (birth-timer = 0) [
      let r round (hive-pollen / 50)
      sprout min (list 1 r) [
        set hive patch-here
        fd random-float 3
        set hive-position patch-here
        set heading random 360
        set size 1.5
        set speed INITIAL_SPEED
        set color gray
        set pollen-carried 0
        set next-task [ -> repos ]
      ]
      set birth-timer 50
    ]
  ]
end


to increase-flower-pollen
  ask patches with [flower? = true] [
    set flower-pollen (flower-pollen + flower-pollen-increase-rate)
    set flower-pollen min list flower-pollen flower-initial-pollen
    let t 255 - (flower-pollen / (flower_max_pollen - flower_min_pollen)) * 255
    set pcolor rgb 255 t t
  ]
end


to plot-pollen
  let i 0
  ask patches with [hive? = true] [
    set-current-plot "pollen"
    set-current-plot-pen word "pollen" i
    plot hive-pollen
    set i i + 1
  ]
end

to-report plot-pollen-hive [index]
  let i 0
  let pollen 0
  ask patches with [hive? = true] [
    if (i = index) [
      set pollen hive-pollen
    ]
    set i i + 1
  ]
  report pollen
end

to-report plot-total-pollen
  let pollen 0
  ask patches with [hive? = true] [
    set pollen (pollen + hive-pollen)
  ]
  report pollen
end

to-report get-flower-pollen
  let total-flower-pollen 0
  ask patches with [ flower? = true ] [
    set total-flower-pollen (total-flower-pollen + flower-pollen)
  ]
  report total-flower-pollen
end
@#$#@#$#@
GRAPHICS-WINDOW
188
10
938
579
-1
-1
11.43
1
10
1
1
1
0
1
1
1
-32
32
-24
24
0
0
1
ticks
30.0

BUTTON
66
94
129
127
go
go
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
61
50
134
83
setup
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

SLIDER
0
182
185
215
num-bees-per-hive
num-bees-per-hive
1
100
47.0
1
1
NIL
HORIZONTAL

SLIDER
7
230
179
263
flower-density
flower-density
0
1
0.83
.01
1
NIL
HORIZONTAL

PLOT
1346
10
1749
286
pollen
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS

PLOT
1756
571
2154
833
Yellow bees (en cours de butinage)
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [color = yellow]"

PLOT
1751
10
2151
288
Pink bees (sur la piste de danse)
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [color = pink]"

PLOT
1345
293
1753
570
Blue bees (en recherche de danse)
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [color = blue]"

PLOT
1756
294
2153
570
Gray bees (au repos)
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles with [color = gray]"

PLOT
1345
573
1754
835
Green vs red bees (succès vs echec lors du butinage)
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"echec" 1.0 0 -2674135 true "" "plot count turtles with [color = red]"
"succes" 1.0 0 -13840069 true "" "plot count turtles with [color = green]"

SLIDER
8
279
181
312
num-hives
num-hives
1
10
5.0
1
1
NIL
HORIZONTAL

SLIDER
9
325
182
358
scout-radius
scout-radius
3
40
3.0
1
1
NIL
HORIZONTAL

PLOT
942
10
1345
286
Pollen Total
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot plot-total-pollen"

PLOT
943
292
1342
571
Total flower pollen
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot get-flower-pollen"

PLOT
947
575
1343
835
Nombre total d'abeille
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count turtles"

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

bee 2
true
0
Polygon -1184463 true false 195 150 105 150 90 165 90 225 105 270 135 300 165 300 195 270 210 225 210 165 195 150
Rectangle -16777216 true false 90 165 212 185
Polygon -16777216 true false 90 207 90 226 210 226 210 207
Polygon -16777216 true false 103 266 198 266 203 246 96 246
Polygon -6459832 true false 120 150 105 135 105 75 120 60 180 60 195 75 195 135 180 150
Polygon -6459832 true false 150 15 120 30 120 60 180 60 180 30
Circle -16777216 true false 105 30 30
Circle -16777216 true false 165 30 30
Polygon -7500403 true true 120 90 75 105 15 90 30 75 120 75
Polygon -16777216 false false 120 75 30 75 15 90 75 105 120 90
Polygon -7500403 true true 180 75 180 90 225 105 285 90 270 75
Polygon -16777216 false false 180 75 270 75 285 90 225 105 180 90
Polygon -7500403 true true 180 75 180 90 195 105 240 195 270 210 285 210 285 150 255 105
Polygon -16777216 false false 180 75 255 105 285 150 285 210 270 210 240 195 195 105 180 90
Polygon -7500403 true true 120 75 45 105 15 150 15 210 30 210 60 195 105 105 120 90
Polygon -16777216 false false 120 75 45 105 15 150 15 210 30 210 60 195 105 105 120 90
Polygon -16777216 true false 135 300 165 300 180 285 120 285

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
