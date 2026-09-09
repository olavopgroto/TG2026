[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$headers = @{ "User-Agent" = "Olavo-TCC/1.0 (olavopgroto15@gmail.com)" }

$titulos = @(
  '2023_Turkey–Syria_earthquakes',
  'Turkey',
  'Syria',
  'Kahramanmaraş',
  'Gaziantep',
  'Aleppo',
  'Recep_Tayyip_Erdoğan',
  'Hatay_Province',
  'Adıyaman',
  'Disaster_and_Emergency_Management_Presidency',
  '2023_Marrakesh–Safi_earthquake',
  'Morocco',
  'Marrakesh',
  'High_Atlas',
  'Mohammed_VI_of_Morocco',
  'Al_Haouz_Province',
  'Taroudant_Province',
  'Chichaoua_Province',
  '2024_Noto_earthquake',
  'Japan',
  'Ishikawa_Prefecture',
  'Noto_Peninsula',
  'Wajima,_Ishikawa',
  'Fumio_Kishida',
  'Suzu,_Ishikawa',
  '2021_Haiti_earthquake',
  'Haiti',
  'Les_Cayes',
  'Jérémie,_Haiti',
  'Ariel_Henry',
  'Nippes_Department',
  '2025_Myanmar_earthquake',
  'Myanmar',
  'Mandalay',
  'Naypyidaw',
  'Min_Aung_Hlaing',
  'Sagaing_Region',
  '2024_United_States_presidential_election',
  'Donald_Trump',
  'Kamala_Harris',
  'Joe_Biden',
  'Republican_Party_(United_States)',
  'Democratic_Party_(United_States)',
  'Electoral_College_(United_States)',
  'JD_Vance',
  'Tim_Walz',
  'United_States_Senate',
  '2024_G20_Rio_de_Janeiro_summit',
  'G20',
  'Rio_de_Janeiro',
  'Luiz_Inácio_Lula_da_Silva',
  'Brazil',
  'United_Nations',
  'World_Bank',
  '2025_United_Nations_Climate_Change_Conference',
  'Belém',
  'United_Nations_Framework_Convention_on_Climate_Change',
  'Paris_Agreement',
  'Amazon_rainforest',
  'Death_and_state_funeral_of_Elizabeth_II',
  'Elizabeth_II',
  'Charles_III',
  'Buckingham_Palace',
  'Westminster_Abbey',
  'British_royal_family',
  'Balmoral_Castle',
  'Operation_London_Bridge',
  'Diego_Maradona',
  'Argentina',
  'Argentina_national_football_team',
  'SSC_Napoli',
  'FC_Barcelona',
  '1986_FIFA_World_Cup',
  'Buenos_Aires',
  'Pope_Benedict_XVI',
  'Pope_Francis',
  'Catholic_Church',
  'Vatican_City',
  'Holy_See',
  'Germany',
  'Kobe_Bryant',
  'Los_Angeles_Lakers',
  'National_Basketball_Association',
  'Gianna_Bryant',
  'Calabasas,_California',
  'Vanessa_Bryant',
  'Apple_Vision_Pro',
  'Apple_Inc.',
  'Tim_Cook',
  'Augmented_reality',
  'VisionOS',
  'Meta_Quest',
  'Threads_(social_network)',
  'Meta_Platforms',
  'Mark_Zuckerberg',
  'Instagram',
  'Twitter',
  'Elon_Musk',
  'X_Corp',
  'Gemini_(language_model)',
  'Google',
  'Sundar_Pichai',
  'Artificial_intelligence',
  'ChatGPT',
  'DeepMind',
  'Bard_(chatbot)',
  'Samsung_Galaxy_S24',
  'Samsung_Electronics',
  'Samsung_Galaxy',
  'Android_(operating_system)',
  'Smartphone',
  'Qualcomm_Snapdragon',
  'James_Webb_Space_Telescope',
  'NASA',
  'European_Space_Agency',
  'Canadian_Space_Agency',
  'Hubble_Space_Telescope',
  'Carina_Nebula',
  'Stephan''s_Quintet',
  'Sagittarius_A*',
  'Event_Horizon_Telescope',
  'Milky_Way',
  'Black_hole',
  'Messier_87',
  'Sagittarius_(constellation)',
  'Perseverance_(rover)',
  'Mars',
  'Jet_Propulsion_Laboratory',
  'Ingenuity_(helicopter)',
  'Jezero_(crater)',
  'Curiosity_(rover)',
  'Artemis_I',
  'Space_Launch_System',
  'Orion_(spacecraft)',
  'Kennedy_Space_Center',
  'Artemis_program',
  'Moon'
)

$falhas = @()
$total = $titulos.Count
$contador = 0

foreach ($t in $titulos) {
    $contador++
    $encoded = [uri]::EscapeDataString($t)
    $url = "https://en.wikipedia.org/api/rest_v1/page/summary/$encoded"
    try {
        Invoke-WebRequest -Uri $url -UseBasicParsing -Headers $headers -ErrorAction Stop | Out-Null
        Write-Host "[$contador/$total] OK   - $t" -ForegroundColor Green
    } catch {
        Write-Host "[$contador/$total] ERRO - $t" -ForegroundColor Red
        $falhas += $t
    }
    Start-Sleep -Milliseconds 400
}

Write-Host ""
Write-Host "=================================="
if ($falhas.Count -eq 0) {
    Write-Host "Todos os $total titulos existem! Nenhuma correcao necessaria." -ForegroundColor Green
} else {
    Write-Host "$($falhas.Count) titulo(s) com problema:" -ForegroundColor Yellow
    $falhas | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
}