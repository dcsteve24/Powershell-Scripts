#Meant to be paired with Windows Task Scheduler to run on the top of the hour
#Plays the current hour and sings Big Bang Theories soft kitty song
#Only accounted for hours I was at work in regards to AM/PM statement.
#-----Was a Joke Thing But Provides way to use Text-to-speech

$hour = (Get-Date).Hour
Add-Type -AssemblyName System.speech
$speak = New-Object System.Speech.Synthesis.SpeechSynthesizer

if ($hour -gt 11) {
    $ampm = "hundred"}
else {
    $ampm = "A M"}

$speak.Speak('The time is' + $hour + $ampm)
$speak.Speak('it is time to sing to Jeff')
Start-Sleep -s 1
$speak.Speak('Soft Kitty, Warm Kitty')
$speak.Speak('Little ball of fur')
$speak.Speak('Happy kitty, sleepy kitty')
$speak.Speak('Purr, Purr, Purr')
