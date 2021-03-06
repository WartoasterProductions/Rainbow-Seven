#------------------------------Constants-------------------------------------#
$hueclock   = 160  #Starting color. I like cyan.                             |
$saturation = 50   #Saturation Constant. Keep below 75 or weird shit happens |
$lightness  = 25   #Lightness  Constant.                                     | 
$refresh    = 830  #Refresh rate in milliseconds. 166 per minute.            |
$nospeed    = 2    #speedy refresh rate in ms                                |
$preface    = '0x' #This is to make the hex conversion easier                |
$mousegrow  = 7    #mouse movement growth    Ideal: 10                       |
$mousedecay = 4    #mouse movement decay     Ideal: 2-5                      |
$UseMouse   = 1    #Use the mouse function or don't. 1 or 0                  |
$UseSL      = 1    #Add Saturation and Lightness to mouse action             |
#----------------------------------------------------------------------------#

$delta = 0
$mousex = [windows.forms.cursor]::Position.y
$mousey = [windows.forms.cursor]::Position.x #Get mouse info right off the bat


#            UNCOMMENT THIS BLOCK IF YOU WOULD LIKE TO RUN THIS WITH NO WINDOW: 
<#
$t = '[DllImport("user32.dll")] public static extern bool ShowWindow(int handle, int state);'
add-type -name win -member $t -namespace native
[native.win]::ShowWindow(([System.Diagnostics.Process]::GetCurrentProcess() | Get-Process).MainWindowHandle, 0)
#>

#Implement the DWM API
$managedCode = @'
using System;
using System.Runtime.InteropServices;
namespace DWM
{
        public static class NativeAPI
        {
                [DllImport("dwmapi.dll", EntryPoint = "#131", PreserveSig = false)]
                public static extern void DwmSetColorizationParameters(ref DWM_COLORIZATION_PARAMS parameters, long uUnknown);
                public struct DWM_COLORIZATION_PARAMS
                {
                        public UInt32 ColorizationColor;
                        public UInt32 ColorizationAfterglow;
                        public UInt32 ColorizationColorBalance;
                        public UInt32 ColorizationAfterglowBalance;
                        public UInt32 ColorizationblurBalance;
                        public UInt32 ColorizationGlassReflectionIntensity;
                        public UInt32 ColorizationOpaqueBlend;
                }
        }
}
'@
Add-Type -TypeDefinition $managedCode -Language CSharp

Function HSLtoDWM ($H,$S,$L) { #Converts Hue, Saturation, and Lightness values into decimal strings used by the DWM API
    $H = [double]($H / 360)
    $S = [double]($S / 100)
    $L = [double]($L / 100)
     if ($s -eq 0) {
        $r = $g = $b = $l
     }
    else {
        $q = if($l -lt 0.5){
            $l * (1 + $s) 
    } else {
        $l + $s - $l * $s
    }
        $p = (2 * $L) - $q
        $r = (Hue-Rgb $p $q ($h + 1/3))
        $g = (Hue-Rgb $p $q $h )
        $b = (Hue-Rgb $p $q ($h - 1/3))
    }
    $r = [Math]::Round($r * 255) 
    $g = [Math]::Round($g * 255)
    $b = [Math]::Round($b * 255) #Round to nearest byte
       
    $xr = '{0:x}' -f [int]$r     
    $xg = '{0:x}' -f [int]$g
    $xb = '{0:x}' -f [int]$b     #Convert bytes to hex
    
    $DWMValue = [string]$preface + [string]$xr + [string]$xg + [string]$xb
    $DWMValue = [convert]::toint32($DWMValue, 16)
    $DWMValue += 4278190080      #Alpha channel value. Equal to 0xFF000000
    return ($DWMValue)           #Concatenate hex values, convert to decimal, add alpha channel
}

function Hue-Rgb ($p, $q, $t) {  #boring math for losers
    if ($t -lt 0) { $t++ }
    if ($t -gt 1) { $t-- } 
    if ($t -lt 1/6) { return ( $p + ($q - $p) * 6 * $t ) } 
    if ($t -lt 1/2) { return $q }    
    if ($t -lt 2/3) { return ($p + ($q - $p) * (2/3 - $t) * 6 ) }
    return $p
}

while(1)                                       #Completely legal infinite loop, I swear
{
if($Hueclock -gt 359){
$Hueclock = 0
}
if($USeMouse -eq 1){
   $lastx = $mousex
   $lasty = $mousey
   $mousex = [windows.forms.cursor]::Position.y
   $mousey = [windows.forms.cursor]::Position.x   #get mouse pos each loop

   if ($lastx -eq $mousex){$delta -= $mousedecay} #the mouse polls faster than the loop, so we grow the mouse movement value instead of having it be boolean.
   else {$delta += $mousegrow}                    #the balance between growth and decay affects the "tail" of the mouse movement. a longer "tail" means
   if ($lasty -eq $mousey){$delta -= $mousedecay} #that the windows flash for longer after the mouse stops moving. Play around with these constants to get a good feel.
   else {$delta += $mousegrow}                    
   if ($delta -lt 1){$delta = 0}
   
   if ($delta -gt 1){Start-Sleep -milliseconds $nospeed}
   else {
       if($refresh -gt 0){Start-Sleep -milliseconds $refresh}
       else{Start-Sleep -milliseconds $nospeed}
   }
}
else{
   if($refresh -gt 0){Start-Sleep -milliseconds $refresh}
   else{Start-Sleep -milliseconds .5}
   }
   
$decidelta = $delta / 15
$duodecidelta = $delta / 20

$modLightness = $lightness + $duodecidelta
if ($modLightness -gt 99){$modLightness = 99}

$modSaturation = $saturation + $decidelta
if ($modsaturation -gt 65){$modsaturation = 65}
if ($UseSL -eq 0){$DWMHue = HSLtoDWM $Hueclock $saturation $Lightness}
else {$DWMHue = HSLtoDWM $Hueclock $modsaturation $modLightness}

$dwmParams = New-Object DWM.NativeAPI+DWM_COLORIZATION_PARAMS    #warning: Weird shit below
$dwmParams.ColorizationColor = $DWMHue                           #Main window color
$dwmParams.ColorizationAfterglow = $DWMHue                       #Secondary overlay color (does NOT have to be the same as Main window color)
$dwmParams.ColorizationColorBalance = 100                        #Secondary saturation value, kinda irrelevant 
$dwmParams.ColorizationAfterglowBalance = 100                    #??? I haven't been able to change this to any effect
$dwmParams.ColorizationblurBalance = 100                         #??? I haven't been able to change this to any effect
$dwmParams.ColorizationGlassReflectionIntensity = 100            #Exactly what it sounds like, the streaky glass effect intensity
$dwmParams.ColorizationOpaqueBlend = 100                         #Should be opacity, I haven't been able to change this to any effect

[DWM.NativeAPI]::DwmSetColorizationParameters([ref]$dwmParams,0) #Writes to the DWM API

$Hueclock++
}