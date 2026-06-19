# Thematic real-life photos (Pexels) — one obvious image per AAC label.
$ErrorActionPreference = 'Continue'
$outDir = Join-Path $PSScriptRoot '..\assets\images'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

function Pex($id) {
  return "https://images.pexels.com/photos/$id/pexels-photo-$id.jpeg?auto=compress&cs=tinysrgb&w=440&h=330&fit=crop"
}

$images = @{
  'phrase_happy.jpg' = Pex 1257110
  'phrase_sad.jpg' = Pex 5739943
  'phrase_angry.jpg' = Pex 6152793
  'phrase_scared.jpg' = Pex 4715323
  'phrase_tired.jpg' = Pex 3970700
  'phrase_sick.jpg' = Pex 5156888
  'phrase_hot.jpg' = Pex 301599
  'phrase_cold.jpg' = Pex 11330688
  'phrase_hungry.jpg' = Pex 1640777
  'phrase_sleepy.jpg' = Pex 3608263
  'phrase_pizza.jpg' = Pex 1144340
  'phrase_rice.jpg' = Pex 723198
  'phrase_bread.jpg' = Pex 1775043
  'phrase_chicken.jpg' = Pex 60616
  'phrase_apple.jpg' = Pex 693999
  'phrase_banana.jpg' = Pex 61127
  'phrase_vegetables.jpg' = Pex 1656660
  'phrase_eggs.jpg' = Pex 162712
  'phrase_cake.jpg' = Pex 1721932
  'phrase_sandwich.jpg' = Pex 61174
  'phrase_water.jpg' = Pex 416528
  'phrase_milk.jpg' = Pex 416755
  'phrase_juice.jpg' = Pex 1431335
  'phrase_soda.jpg' = Pex 50593
  'phrase_coffee.jpg' = Pex 302899
  'phrase_tea.jpg' = Pex 1416530
  'phrase_ice_cream.jpg' = Pex 1352278
  'phrase_sleep.jpg' = Pex 5264003
  'phrase_play.jpg' = Pex 2256824
  'phrase_eat.jpg' = Pex 1640770
  'phrase_home.jpg' = Pex 106399
  'phrase_tv.jpg' = Pex 12019911
  'phrase_read.jpg' = Pex 256455
  'phrase_draw.jpg' = Pex 3558517
  'phrase_dance.jpg' = Pex 5712513
  'phrase_swim.jpg' = Pex 1268855
  'phrase_run.jpg' = Pex 589763
  'phrase_dog.jpg' = Pex 1805164
  'phrase_cat.jpg' = Pex 45201
  'phrase_bird.jpg' = Pex 1661170
  'phrase_fish.jpg' = Pex 128756
  'phrase_cow.jpg' = Pex 2071772
  'phrase_horse.jpg' = Pex 1996336
  'phrase_rabbit.jpg' = Pex 1392598
  'phrase_butterfly.jpg' = Pex 326055
  'phrase_help.jpg' = Pex 7119553
  'phrase_bathroom.jpg' = Pex 1454804
  'phrase_break.jpg' = Pex 3771069
  'phrase_medicine.jpg' = Pex 4035793
  'phrase_rest.jpg' = Pex 3771069
  'phrase_quiet.jpg' = Pex 1181519
  'phrase_hurt.jpg' = Pex 6749718
  'phrase_glasses.jpg' = Pex 1576746
  'phrase_hello.jpg' = Pex 8613327
  'phrase_goodbye.jpg' = Pex 8613087
  'phrase_thank_you.jpg' = Pex 6646914
  'phrase_please.jpg' = Pex 4260324
  'phrase_yes.jpg' = Pex 699459
  'phrase_no.jpg' = Pex 18509431
  'phrase_more.jpg' = Pex 5938
  'phrase_stop.jpg' = Pex 13666399
  'phrase_sorry.jpg' = Pex 774909
  'phrase_school.jpg' = Pex 256541
  'phrase_homework.jpg' = Pex 8076817
  'phrase_pencil.jpg' = Pex 1670994
  'phrase_book.jpg' = Pex 159711
  'phrase_recess.jpg' = Pex 8612997
  'phrase_teacher.jpg' = Pex 5212339
  'phrase_headache.jpg' = Pex 6749718
  'phrase_sick_day.jpg' = Pex 5156888
  'phrase_park.jpg' = Pex 158023
  'phrase_store.jpg' = Pex 264636
  'phrase_hospital.jpg' = Pex 263402
  'phrase_outside.jpg' = Pex 1133950
  'phrase_bedroom.jpg' = Pex 2724747
  'phrase_classroom.jpg' = Pex 256466
}

$ok = 0
$fail = @()
foreach ($entry in $images.GetEnumerator()) {
  $dest = Join-Path $outDir $entry.Key
  Write-Host "get $($entry.Key)"
  try {
    Invoke-WebRequest -Uri $entry.Value -OutFile $dest -UseBasicParsing
    if ((Get-Item $dest).Length -gt 3000) { $ok++ } else { $fail += $entry.Key; Remove-Item $dest -Force -ErrorAction SilentlyContinue }
  } catch {
    Write-Warning "failed $($entry.Key): $_"
    $fail += $entry.Key
  }
}
Write-Host "Done. ok=$ok fail=$($fail.Count)"
if ($fail.Count -gt 0) { Write-Host ($fail -join ', ') }
