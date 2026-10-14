; Script de Inno Setup para generar el instalador de Windows.
;
; Produce un único rundown-setup-<versión>.exe autocontenido: incluye el
; ejecutable, los DLLs de Flutter y de los plugins, y la carpeta `data/`.
; El usuario final recibe un solo archivo.
;
; La versión se inyecta desde el workflow con /DAppVersion=...
; Compilar a mano:
;   ISCC.exe /DAppVersion=1.0.0 installer\rundown.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

#define AppName "Rundown Timer"
#define AppPublisher "edensfj"
#define AppExeName "rundown.exe"
#define SourceDir "..\build\windows\x64\runner\Release"

[Setup]
; AppId fija la identidad de la app: permite que una versión nueva actualice
; la anterior en vez de instalarse en paralelo. No cambiar nunca.
AppId={{D74BB7A7-EEBD-4D36-B3CF-157E90D523F5}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
VersionInfoVersion={#AppVersion}

; Sin UAC: se instala en el perfil del usuario. Se puede cambiar la carpeta.
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
AllowNoIcons=yes

; Un solo archivo de salida, con compresión máxima.
OutputDir=..\dist
OutputBaseFilename=rundown-setup-{#AppVersion}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0

; Icono del propio instalador y de la entrada en "Aplicaciones instaladas".
SetupIconFile=..\assets\icon\rundown-icon.ico

; Permite actualizar con la app abierta.
CloseApplications=yes
RestartApplications=no

UninstallDisplayName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Se copia la carpeta Release completa: exe + DLLs + data/.
; `data\` contiene flutter_assets (con la fuente Oswald) e icudtl.dat.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
// El itinerario vive en %APPDATA%. No se borra por defecto: se pregunta.
// Ruta real: getApplicationSupportDirectory() de path_provider usa
// CompanyName\ProductName del VERSIONINFO del exe, y Hive añade 'rundown'.
function InitializeUninstall(): Boolean;
var
  DataDir: String;
begin
  Result := True;
  DataDir := ExpandConstant('{userappdata}\edensfj\Rundown Timer\rundown');

  if not DirExists(DataDir) then
    exit;

  if MsgBox('Se encontró el itinerario guardado en:' + #13#10 + #13#10 +
            DataDir + #13#10 + #13#10 +
            '¿Quieres borrarlo también? Si eliges No, se conservará por si ' +
            'reinstalas más adelante.',
            mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then
    DelTree(DataDir, True, True, True);
end;
