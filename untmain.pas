unit untmain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  ComCtrls, Menus, IdHTTP, JsonTools, Contnrs, Process, Math, Variants,
  DateUtils, DOM, XMLWrite, FileUtil;

type

  TInstance = class
  private
    FID               : Integer; // Instance ID
    FName             : string;  // Instance name
    FAPIKey           : string;  // Instance HTTP_API Key
    FFileNamingMovies : Integer; // Movies file-naming
    FMoviesFolder     : string;  // Movies STRM output folder
    FFileNamingSeries : Integer; // Series file-naming
    FSeriesFolder     : string;  // Series STRM output folder
    FCreateNFO        : Boolean; // Create NFO files
    FOverwriteFiles   : Boolean; // Overwrite existing files
    FDeleteRemoved    : Boolean; // Delete removed Movies and Series
  public
    constructor Create(const AID: Integer; const AName: string; const AAPIKey: string; const AFileNamingMovies: Integer; const AMoviesFolder: string; const AFileNamingSeries: Integer; const ASeriesFolder: string; const ACreateNFO: Boolean; const AOverwriteFiles: Boolean; const ADeleteRemoved: Boolean); virtual;

    property ID: Integer read FID;
    property Name: string read FName;
    property APIKey: string read FAPIKey;
    property FileNamingMovies: Integer read FFileNamingMovies;
    property MoviesFolder: string read FMoviesFolder;
    property FileNamingSeries: Integer read FFileNamingSeries;
    property SeriesFolder: string read FSeriesFolder;
    property CreateNFO: Boolean read FCreateNFO;
    property OverwriteFiles: Boolean read FOverwriteFiles;
    property DeleteRemoved: Boolean read FDeleteRemoved;
  end;

  { TfrmMain }

  TfrmMain = class(TForm)
    About: TMenuItem;
    btnLogin: TButton;
    btnStart: TButton;
    btnStop: TButton;
    cbInstances: TComboBox;
    edtPassword: TEdit;
    edtUsername: TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    HTTP_API: TIdHTTP;
    Image1: TImage;
    Label1: TLabel;
    Label2: TLabel;
    lblProgress: TLabel;
    MenuItem2: TMenuItem;
    N1: TMenuItem;
    ProgressBar: TProgressBar;
    TrayIcon: TTrayIcon;
    TrayPopup: TPopupMenu;
    procedure AboutClick(Sender: TObject);
    procedure btnLoginClick(Sender: TObject);
    procedure btnStartClick(Sender: TObject);
    procedure btnStopClick(Sender: TObject);
    procedure cbInstancesChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure MenuItem2Click(Sender: TObject);
  private
    FInstances  : TFPObjectList;
    FFileList   : TStringList;
    FFolderList : TStringList;
    FCancel     : Boolean;
  public
    property Instances: TFPObjectList read FInstances;
    property FileList: TStringList read FFileList;
    property FolderList: TStringList read FFolderList;
    property Cancel: Boolean read FCancel write FCancel;

    function Icon : string;
    function Alert(const ATitle: string; const AText: string) : Boolean;
    function Login(const Username: string; const Password: string) : Boolean;

    procedure SaveSettings;
    procedure LoadSettings(const LoggedIn: Boolean = false);

    procedure ConvertMovies(const Instance: TInstance);
    procedure ConvertSeries(const Instance: TInstance);
    procedure CleanUpRemoved(const Directory: string);
  end;

var
  frmMain: TfrmMain;

const
  ApplicationTitle = 'M3U 2 STRM by IPTV-Tools.com';
  AlertTitle       = 'M3U 2 STRM';
  {$IFDEF UNIX}
    AboutText      = 'M3U 2 STRM v1.0 (for Linux)' + sLineBreak + 'By IPTV-Tools.com' + sLineBreak + sLineBreak + 'a product of ERDesigns - Ernst Reidinga.' + sLineBreak +  sLineBreak + 'https://iptv-tools.com' + sLineBreak + 'https://erdesigns.eu' + sLineBreak + 'https://fb.me/erdesignseu';
  {$ENDIF}
  {$IFDEF WINDOWS}
    AboutText      = 'M3U 2 STRM v1.0 (for Windows)' + sLineBreak + 'By IPTV-Tools.com' + sLineBreak + sLineBreak + 'a product of ERDesigns - Ernst Reidinga.' + sLineBreak +  sLineBreak + 'https://iptv-tools.com' + sLineBreak + 'https://erdesigns.eu' + sLineBreak + 'https://fb.me/erdesignseu';
  {$ENDIF}
  {$IFDEF DARWIN}
    AboutText      = 'M3U 2 STRM v1.0 (for MacOS)' + sLineBreak + 'By IPTV-Tools.com' + sLineBreak + sLineBreak + 'a product of ERDesigns - Ernst Reidinga.' + sLineBreak +  sLineBreak + 'https://iptv-tools.com' + sLineBreak + 'https://erdesigns.eu' + sLineBreak + 'https://fb.me/erdesignseu';
  {$ENDIF}

implementation

{$R *.frm}

function EscapeIllegalChars(AString: string) : string;
var
  X : Integer;
const
  {$IFDEF UNIX}
    IllegalCharSet: set of char = ['/'];
  {$ENDIF}

  {$IFDEF WINDOWS}
    IllegalCharSet: set of char = ['|','<','>','\','^','+','=','?','/','[',']','"',';',',','*'];
  {$ENDIF}
begin
  for X := 1 to Length(AString) do if AString[X] in IllegalCharSet then AString[X] := ' ';
  Result := AString;
end;

// M3U 2 STRM Instances
constructor TInstance.Create(const AID: Integer; const AName: string; const AAPIKey: string; const AFileNamingMovies: Integer; const AMoviesFolder: string; const AFileNamingSeries: Integer; const ASeriesFolder: string; const ACreateNFO: Boolean; const AOverwriteFiles: Boolean; const ADeleteRemoved: Boolean);
begin
  inherited Create;
  FID               := AID;
  FName             := AName;
  FAPIKey           := AAPIKey;
  FFileNamingMovies := AFileNamingMovies;
  FMoviesFolder     := AMoviesFolder;
  FFileNamingSeries := AFileNamingSeries;
  FSeriesFolder     := ASeriesFolder;
  FCreateNFO        := ACreateNFO;
  FOverwriteFiles   := AOverwriteFiles;
  FDeleteRemoved    := ADeleteRemoved;
end;

// Icon for alert
function TfrmMain.Icon : string;
begin
  Result := '--icon=' + ExtractFilePath(Paramstr(0)) + 'Icon.png';
end;

// Alert
function TfrmMain.Alert(const ATitle: string; const AText: string) : Boolean;
var
  S : AnsiString;
begin
  {$IFDEF UNIX}
    Result := RunCommand('notify-send',[ATitle, AText, Icon], S);
  {$ENDIF}

  {$IFDEF WINDOWS}
    TrayIcon.BalloonTitle := ATitle;
    TrayIcon.BalloonHint  := AText;
    TrayIcon.BalloonFlags := bfInfo;
    TrayIcon.ShowBalloonHint;
  {$ENDIF}
end;

// Login
function TfrmMain.Login(const Username: string; const Password: string) : Boolean;
var
  PN : TJsonNode;
  PS : TStringList;
  RN : TJsonNode;
  RS : TStringStream;
  I  : TJsonNode;
begin
  PN := TJsonNode.Create;
  PS := TStringList.Create;
  RN := TJsonNode.Create;
  RS := TStringStream.Create;
  try
    PN.Add('username', Username);
    PN.Add('password', Password);
    PS.Text := PN.AsJson;
    HTTP_API.Post('http://strm.iptv-tools.com/authenticate', PS, RS);
    if RN.TryParse(RS.DataString) then
    begin
      Result := RN.Find('status').AsBoolean;
      if Result then
      begin
        // Clear instances list
        Instances.Clear;
        // Add instances
        for I in RN.Find('data').AsArray do
        begin
          Instances.Add(TInstance.Create(
            Trunc(I.Find('id').AsNumber),
            I.Find('name').AsString,
            I.Find('api_key').AsString,
            Trunc(I.Find('file_naming_movies').AsNumber),
            I.Find('movies_folder').AsString,
            Trunc(I.Find('file_naming_series').AsNumber),
            I.Find('series_folder').AsString,
            Trunc(I.Find('create_nfo').AsNumber) = 1,
            Trunc(I.Find('overwrite_files').AsNumber) = 1,
            Trunc(I.Find('delete_removed').AsNumber) = 1
          ));
        end;
      end;
    end else
      Result := False;
  finally
    PN.Free;
    PS.Free;
    RN.Free;
    RS.Free;
  end;
end;

// Save settings to JSON file
procedure TfrmMain.SaveSettings;
var
  SF : TStringList;
  SJ : TJsonNode;
  FN : string;
begin
  SF := TStringList.Create;
  SJ := TJsonNode.Create;
  FN := ExtractFilePath(Paramstr(0)) + 'm3u2strm.conf';
  try
    SJ.Add('username', edtUsername.Text);
    SJ.Add('password', edtPassword.Text);
    SJ.Add('instance', cbInstances.ItemIndex);
    SF.Text := SJ.AsJson;
    SF.SaveToFile(FN);
  finally
    SF.Free;
    SJ.Free;
  end;
end;

// Load settings from JSON file
procedure TfrmMain.LoadSettings(const LoggedIn: Boolean = false);
var
  SF : TStringList;
  SJ : TJsonNode;
  FN : string;
begin
  SF := TStringList.Create;
  SJ := TJsonNode.Create;
  FN := ExtractFilePath(Paramstr(0)) + 'm3u2strm.conf';
  try
    if FileExists(FN) then
    begin
      SF.LoadFromFile(FN);
      if SJ.TryParse(SF.Text) then
      begin
        if LoggedIn then
          cbInstances.ItemIndex := Trunc(SJ.Find('instance').AsNumber)
        else
        begin
          edtUsername.Text := SJ.Find('username').AsString;
          edtPassword.Text := SJ.Find('password').AsString;
        end;
      end;
    end;
  finally
    SF.Free;
    SJ.Free;
  end;
end;

// Convert Movies to STRM files
procedure TfrmMain.ConvertMovies(const Instance: TInstance);
var
  STRM : TStringList;

  function GetTotalMovies : Integer;
  var
    PN : TJsonNode;
    PS : TStringList;
    RN : TJsonNode;
    RS : TStringStream;
  begin
    Result := 0;
    PN := TJsonNode.Create;
    PS := TStringList.Create;
    RN := TJsonNode.Create;
    RS := TStringStream.Create;
    try
      PN.Add('api_key', Instance.APIKey);
      PS.Text := PN.AsJson;
      HTTP_API.Post('http://strm.iptv-tools.com/total-movies', PS, RS);
      if RN.TryParse(RS.DataString) then
      begin
        if RN.Find('status').AsBoolean then
        begin
           Result := Trunc(RN.Find('data').AsNumber);
        end;
      end;
    finally
      PN.Free;
      PS.Free;
      RN.Free;
      RS.Free;
    end;
  end;

  function GetMovies(const From: Integer; const Limit: Integer) : string;
  var
    PN : TJsonNode;
    PS : TStringList;
    RS : TStringStream;
  begin
    Result := '';
    PN := TJsonNode.Create;
    PS := TStringList.Create;
    RS := TStringStream.Create;
    try
      PN.Add('api_key', Instance.APIKey);
      PN.Add('from', From);
      PN.Add('limit', Limit);
      PS.Text := PN.AsJson;
      HTTP_API.Post('http://strm.iptv-tools.com/movies', PS, RS);
      Result := RS.DataString;
    finally
      PN.Free;
      PS.Free;
      RS.Free;
    end;
  end;

  procedure CreateNFO(const Movie: TJsonNode; const Filename: string);
  var
    Genre                           : TJsonNode;
    Doc                             : TXMLDocument;
    RootNode, parentNode, childNode : TDOMNode;
  begin
    if (Movie.Find('tmdb/success') <> nil) and (Movie.Find('tmdb/success').AsBoolean = False) then Exit;
    try
      // Create a document
      Doc := TXMLDocument.Create;

      // Create a root node
      RootNode := Doc.CreateElement('movie');
      Doc.Appendchild(RootNode);

      // Title
      parentNode := Doc.CreateElement('title');
      childNode := Doc.CreateTextNode(Movie.Find('tmdb/title').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);

      // Original Title
      parentNode := Doc.CreateElement('originaltitle');
      childNode := Doc.CreateTextNode(Movie.Find('tmdb/original_title').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);

      // Plot
      parentNode := Doc.CreateElement('plot');
      childNode := Doc.CreateTextNode(Movie.Find('tmdb/overview').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);;

      // Tagline
      parentNode := Doc.CreateElement('tagline');
      childNode := Doc.CreateTextNode(Movie.Find('tmdb/tagline').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);

      // Runtime
      parentNode := Doc.CreateElement('runtime');
      childNode := Doc.CreateTextNode(Movie.Find('tmdb/runtime').AsNumber.ToString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);;

      // Unique ID (TMDB ID)
      parentNode := Doc.CreateElement('uniqueid');
      TDOMElement(parentNode).SetAttribute('type', 'tmdb');
      TDOMElement(parentNode).SetAttribute('default', 'true');
      childNode := Doc.CreateTextNode(Movie.Find('tmdb/id').AsNumber.ToString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);;

      // Genre
      for Genre in Movie.Find('tmdb/genres').AsArray do
      begin
        parentNode := Doc.CreateElement('genre');
        childNode := Doc.CreateTextNode(Genre.Find('name').AsString);
        parentNode.Appendchild(childNode);
        RootNode.Appendchild(parentNode);
      end;

      // Premiered
      parentNode := Doc.CreateElement('premiered');
      childNode := Doc.CreateTextNode(Movie.Find('tmdb/release_date').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);

      try
        WriteXMLFile(Doc, Filename);
      except
      end;
    finally
      Doc.Free;
    end;
  end;

  procedure CreateSTRM(const Movie: TJsonNode);
  var
    FilePath   : string;
    MovieYear  : string;
    MovieTitle : string;
  begin
    Application.ProcessMessages;

    // Set STRM content
    if Movie.Find('stream_is_custom').AsBoolean then
      STRM.Text := Movie.Find('source_stream_url').AsString
    else
      STRM.Text := Movie.Find('xtream_url').AsString;

    // Movie Year
    MovieYear := Trunc(Movie.Find('movie_year').AsNumber).ToString;

    // Set movie title
    if MovieYear.IsEmpty then
      MovieTitle := EscapeIllegalChars(Format('%s', [Movie.Find('tmdb/title').AsString]))
    else
      MovieTitle := EscapeIllegalChars(Format('%s (%s)', [Movie.Find('tmdb/title').AsString, MovieYear]));

    // Update progression label
    lblProgress.Caption := MovieTitle;

    // File path depending on settings for instance
    case Instance.FileNamingMovies of

      // Movie folder/Group Name/Movie Name/Movie.strm
      1 : begin
            FilePath := IncludeTrailingPathDelimiter(Instance.MoviesFolder) + EscapeIllegalChars(Movie.Find('group_name').AsString) + PathDelim + MovieTitle + PathDelim;
            FolderList.Add(ExcludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(Instance.MoviesFolder) + EscapeIllegalChars(Movie.Find('group_name').AsString)));
          end;

      // Movie folder/Movie Name/Movie.strm
      2 : begin
            FilePath := IncludeTrailingPathDelimiter(Instance.MoviesFolder) + MovieTitle + PathDelim;
          end;

      // Movie folder/Movie.strm
      3: begin
           FilePath := IncludeTrailingPathDelimiter(Instance.MoviesFolder);
         end;
    end;

    // Add path and files to file list
    FolderList.Add(ExcludeTrailingPathDelimiter(FilePath));
    FileList.Add(FilePath + MovieTitle + '.strm');
    FileList.Add(FilePath + MovieTitle + '.nfo');

    // Check if folder exists - else create one
    if not DirectoryExists(FilePath) then ForceDirectories(FilePath);

    // Dont write file if it already exists
    if (not Instance.OverwriteFiles) and FileExists(FilePath + MovieTitle + '.strm') then Exit;

    // Write to STRM file
    try
      if DirectoryExists(FilePath) then STRM.SaveToFile(FilePath + MovieTitle + '.strm');
    except
    end;

    // Write NFO file?
    if Instance.CreateNFO then CreateNFO(Movie, FilePath + MovieTitle + '.nfo');
  end;

const
  Limit = 100;
var
  Total  : Integer;
  I      : Integer;
  Movies : TJsonNode;
  Movie  : TJsonNode;
begin
  Cancel := False;

  // If there is no folder set just exit.
  if Instance.MoviesFolder.IsEmpty then Exit;

  // Check if folder exists, or create one
  if not DirectoryExists(Instance.MoviesFolder) then
  if not ForceDirectories(Instance.MoviesFolder) then
  begin
    Alert(AlertTitle, 'Invalid Movies folder! Movies STRM generation canceled!');
    Exit;
  end;

  // Create STRM (Stringlist that we share for each strm file generation).
  STRM := TStringList.Create;
  try
    // Total Movies
    Total := GetTotalMovies;

    // Set progression
    lblProgress.Caption := Format('Total %d movies', [Total]);
    // Set Progressbar max
    ProgressBar.Max := Total;
    ProgressBar.Position := 0;

    // Add movie folder to file list
    FolderList.Add(IncludeTrailingPathDelimiter(Instance.MoviesFolder));

    // Loop to get the movies
    for I := 0 to Ceil(Total / 100) do
    begin
      if Cancel then Break;
      Movies := TJsonNode.Create;
      try
        if Movies.TryParse(GetMovies(I * Limit, Limit)) then
        begin
          if Movies.Find('status').AsBoolean then
          for Movie in Movies.Find('data').AsArray do
          begin
            Application.ProcessMessages;
            if Cancel then Break;
            ProgressBar.StepIt;
            CreateSTRM(Movie);
          end;
        end;
      finally
        Movies.Free;
      end;
    end;
  finally
    STRM.Free;
  end;

  // Set progress to zero
  ProgressBar.Position := 0;
  lblProgress.Caption  := '';
end;

// Convert Series to STRM files
procedure TfrmMain.ConvertSeries(const Instance: TInstance);
var
  STRM : TStringList;

  function GetTotalSeries : Integer;
  var
    PN : TJsonNode;
    PS : TStringList;
    RN : TJsonNode;
    RS : TStringStream;
  begin
    Result := 0;
    PN := TJsonNode.Create;
    PS := TStringList.Create;
    RN := TJsonNode.Create;
    RS := TStringStream.Create;
    try
      PN.Add('api_key', Instance.APIKey);
      PS.Text := PN.AsJson;
      HTTP_API.Post('http://strm.iptv-tools.com/total-series', PS, RS);
      if RN.TryParse(RS.DataString) then
      begin
        if RN.Find('status').AsBoolean then
        begin
           Result := Trunc(RN.Find('data').AsNumber);
        end;
      end;
    finally
      PN.Free;
      PS.Free;
      RN.Free;
      RS.Free;
    end;
  end;

  function GetSeries(const From: Integer; const Limit: Integer) : string;
  var
    PN : TJsonNode;
    PS : TStringList;
    RS : TStringStream;
  begin
    Result := '';
    PN := TJsonNode.Create;
    PS := TStringList.Create;
    RS := TStringStream.Create;
    try
      PN.Add('api_key', Instance.APIKey);
      PN.Add('from', From);
      PN.Add('limit', Limit);
      PS.Text := PN.AsJson;
      HTTP_API.Post('http://strm.iptv-tools.com/series', PS, RS);
      Result := RS.DataString;
    finally
      PN.Free;
      PS.Free;
      RS.Free;
    end;
  end;

  function GetEpisodes(const TMDB_ID: string) : string;
  var
    PN : TJsonNode;
    PS : TStringList;
    RS : TStringStream;
  begin
    Result := '';
    PN := TJsonNode.Create;
    PS := TStringList.Create;
    RS := TStringStream.Create;
    try
      PN.Add('api_key', Instance.APIKey);
      PN.Add('tmdb_id', TMDB_ID);
      PS.Text := PN.AsJson;
      HTTP_API.Post('http://strm.iptv-tools.com/episodes', PS, RS);
      Result := RS.DataString;
    finally
      PN.Free;
      PS.Free;
      RS.Free;
    end;
  end;

  procedure CreateTVShowNFO(const Serie: TJsonNode; const Filename: string);
  var
    Genre                           : TJsonNode;
    Doc                             : TXMLDocument;
    RootNode, parentNode, childNode : TDOMNode;
  begin
    if (Serie.Find('tmdb/success') <> nil) and (Serie.Find('tmdb/success').AsBoolean = False) then Exit;
    try
      // Create a document
      Doc := TXMLDocument.Create;

      // Create a root node
      RootNode := Doc.CreateElement('tvshow');
      Doc.Appendchild(RootNode);

      // Title
      parentNode := Doc.CreateElement('title');
      childNode := Doc.CreateTextNode(Serie.Find('tmdb/name').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);

      // Original Title
      parentNode := Doc.CreateElement('originaltitle');
      childNode := Doc.CreateTextNode(Serie.Find('tmdb/original_name').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);

      // Plot
      parentNode := Doc.CreateElement('plot');
      childNode := Doc.CreateTextNode(Serie.Find('tmdb/overview').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);;

      // Tagline
      parentNode := Doc.CreateElement('tagline');
      childNode := Doc.CreateTextNode(Serie.Find('tmdb/tagline').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);

      // Unique ID (TMDB ID)
      parentNode := Doc.CreateElement('uniqueid');
      TDOMElement(parentNode).SetAttribute('type', 'tmdb');
      TDOMElement(parentNode).SetAttribute('default', 'true');
      childNode := Doc.CreateTextNode(Serie.Find('tmdb/id').AsNumber.ToString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);;

      // Genre
      for Genre in Serie.Find('tmdb/genres').AsArray do
      begin
        parentNode := Doc.CreateElement('genre');
        childNode := Doc.CreateTextNode(Genre.Find('name').AsString);
        parentNode.Appendchild(childNode);
        RootNode.Appendchild(parentNode);
      end;

      // Premiered
      parentNode := Doc.CreateElement('premiered');
      childNode := Doc.CreateTextNode(Serie.Find('tmdb/first_air_date').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);

      try
        WriteXMLFile(Doc, Filename);
      except
      end;
    finally
      Doc.Free;
    end;
  end;

  procedure CreateEpisodeNFO(const Episode: TJsonNode; const Filename: string);
  var
    Doc                             : TXMLDocument;
    RootNode, parentNode, childNode : TDOMNode;
  begin
    if (Episode.Find('tmdb/success') <> nil) and (Episode.Find('tmdb/success').AsBoolean = False) then Exit;
    try
      // Create a document
      Doc := TXMLDocument.Create;

      // Create a root node
      RootNode := Doc.CreateElement('episodedetails');
      Doc.Appendchild(RootNode);

      // Title
      parentNode := Doc.CreateElement('title');
      childNode := Doc.CreateTextNode(Episode.Find('tmdb/name').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);

      // Plot
      parentNode := Doc.CreateElement('plot');
      childNode := Doc.CreateTextNode(Episode.Find('tmdb/overview').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);;

      // Unique ID (TMDB ID)
      parentNode := Doc.CreateElement('uniqueid');
      TDOMElement(parentNode).SetAttribute('type', 'tmdb');
      TDOMElement(parentNode).SetAttribute('default', 'true');
      childNode := Doc.CreateTextNode(Episode.Find('tmdb/id').AsNumber.ToString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);;

      // Aired
      parentNode := Doc.CreateElement('aired');
      childNode := Doc.CreateTextNode(Episode.Find('tmdb/air_date').AsString);
      parentNode.Appendchild(childNode);
      RootNode.Appendchild(parentNode);

      try
        WriteXMLFile(Doc, Filename);
      except
      end;
    finally
      Doc.Free;
    end;
  end;

  procedure CreateSTRM(const Serie: TJsonNode; const Episode: TJsonNode);
  var
    FilePath     : string;
    ShowPath     : string;
    SerieYear    : string;
    SerieTitle   : string;
    SerieSeason  : string;
    EpisodeTitle : string;
  begin
    Application.ProcessMessages;

    // Set STRM content
    if Episode.Find('stream_is_custom').AsBoolean then
      STRM.Text := Episode.Find('source_stream_url').AsString
    else
      STRM.Text := Episode.Find('xtream_url').AsString;

    // Serie Year
    if (Episode.Find('serie_year').AsNumber > 0) then
    SerieYear := Trunc(Episode.Find('serie_year').AsNumber).ToString;

    // Set episode title
    if SerieYear.IsEmpty then
      EpisodeTitle := EscapeIllegalChars(Format('%s S%.2dE%.2d', [Serie.Find('tmdb/name').AsString, Trunc(Episode.Find('serie_season').AsNumber), Trunc(Episode.Find('serie_episode').AsNumber)]))
    else
      EpisodeTitle := EscapeIllegalChars(Format('%s (%s) S%.2dE%.2d', [Serie.Find('tmdb/name').AsString, SerieYear, Trunc(Episode.Find('serie_season').AsNumber), Trunc(Episode.Find('serie_episode').AsNumber)]));

    // Set serie title
    if SerieYear.IsEmpty then
      SerieTitle := EscapeIllegalChars(Format('%s', [Serie.Find('tmdb/name').AsString]))
    else
      SerieTitle := EscapeIllegalChars(Format('%s (%s)', [Serie.Find('tmdb/name').AsString, SerieYear]));

    // Set serie season title
    SerieSeason := Format('Season %d', [Trunc(Episode.Find('serie_season').AsNumber)]);

    // Update progression label
    lblProgress.Caption := SerieTitle;

    // File path depending on settings for instance
    case Instance.FileNamingSeries of
      // Series folder/Group Name/Series Name/Season/Series.strm
      1 : begin
            FilePath := IncludeTrailingPathDelimiter(Instance.SeriesFolder) + EscapeIllegalChars(Episode.Find('group_name').AsString) + PathDelim + SerieTitle + PathDelim + SerieSeason + PathDelim;
            ShowPath := IncludeTrailingPathDelimiter(Instance.SeriesFolder) + EscapeIllegalChars(Episode.Find('group_name').AsString) + PathDelim + SerieTitle + PathDelim;
            FolderList.Add(ExcludeTrailingPathDelimiter(IncludeTrailingPathDelimiter(Instance.SeriesFolder) + EscapeIllegalChars(Episode.Find('group_name').AsString)));
          end;

      // Series folder/Series Name/Season/Series.strm
      2 : begin
            FilePath := IncludeTrailingPathDelimiter(Instance.SeriesFolder) + SerieTitle + PathDelim + SerieSeason + PathDelim;
            ShowPath := IncludeTrailingPathDelimiter(Instance.SeriesFolder) + SerieTitle + PathDelim;
          end;

      // Series folder/Series.strm
      3: begin
          FilePath := IncludeTrailingPathDelimiter(Instance.SeriesFolder);
          ShowPath := IncludeTrailingPathDelimiter(Instance.SeriesFolder);
         end;
    end;

    // Add path and files to file list
    FolderList.Add(ExcludeTrailingPathDelimiter(FilePath));
    FolderList.Add(ExcludeTrailingPathDelimiter(ShowPath));
    FileList.Add(ShowPath + 'tvshow.nfo');
    FileList.Add(FilePath + EpisodeTitle + '.strm');
    FileList.Add(FilePath + EpisodeTitle + '.nfo');

    // Check if folder exists - else create one
    if not DirectoryExists(FilePath) then ForceDirectories(FilePath);

    // Dont write file if it already exists
    if (not Instance.OverwriteFiles) and FileExists(FilePath + EpisodeTitle + '.strm') then Exit;

    // Write to STRM file
    try
      if DirectoryExists(FilePath) then STRM.SaveToFile(FilePath + EpisodeTitle + '.strm');
    except
    end;

    // Write NFO file?
    if Instance.CreateNFO then
    begin
      CreateTVShowNFO(Serie, ShowPath + 'tvshow.nfo');
      CreateEpisodeNFO(Episode, FilePath + EpisodeTitle + '.nfo');
    end;
  end;

const
  Limit = 100;
var
  Total    : Integer;
  I        : Integer;
  Series   : TJsonNode;
  Serie    : TJsonNode;
  Episodes : TJsonNode;
  Episode  : TJsonNode;
begin
  Cancel := False;

  // If there is no folder set just exit.
  if Instance.SeriesFolder.IsEmpty then Exit;

  // Check if folder exists, or create one
  if not DirectoryExists(Instance.SeriesFolder) then
  if not ForceDirectories(Instance.SeriesFolder) then
  begin
    Alert(AlertTitle, 'Invalid Series folder! Series STRM generation canceled!');
    Exit;
  end;

  // Create STRM (Stringlist that we share for each strm file generation).
  STRM := TStringList.Create;
  try
    // Total Series
    Total := GetTotalSeries;

    // Set progression
    lblProgress.Caption := Format('Total %d series', [Total]);
    // Set Progressbar max
    ProgressBar.Max := Total;
    ProgressBar.Position := 0;

    // Add series folder to file list
    FolderList.Add(ExcludeTrailingPathDelimiter(Instance.SeriesFolder));

    // Loop to get the movies
    for I := 0 to Ceil(Total / 100) do
    begin
      if Cancel then Break;
      Series := TJsonNode.Create;
      try
        if Series.TryParse(GetSeries(I * Limit, Limit)) then
        begin
          if Series.Find('status').AsBoolean then
          for Serie in Series.Find('data').AsArray do
          begin
            if Cancel then Break;
            ProgressBar.StepIt;
            Episodes := TJsonNode.Create;
            Application.ProcessMessages;
            try
              if Episodes.TryParse(GetEpisodes(Trunc(Serie.Find('tmdb_id').AsNumber).ToString)) then
              begin
                if Episodes.Find('status').AsBoolean then
                for Episode in Episodes.Find('data').AsArray do
                begin
                  if Cancel then Break;
                  CreateSTRM(Serie, Episode);
                end;
              end;
            finally
              Episodes.Free;
            end;
          end;
        end;
      finally
        Series.Free;
      end;
    end;
  finally
    STRM.Free;
  end;

  // Set progress to zero
  ProgressBar.Position := 0;
  lblProgress.Caption  := '';
end;

procedure TfrmMain.CleanUpRemoved(const Directory: string);
var
  ActualFiles   : TStringList;
  ActualFolders : TStringList;
  I, X          : Integer;
begin
  ActualFiles   := TStringList.Create;
  ActualFolders := TStringList.Create;
  try
    // Files
    FindAllFiles(ActualFiles, Directory, '*.*', True);
    // Loop over files
    ProgressBar.Max := ActualFiles.Count;
    for I := 0 to ActualFiles.Count -1 do
    begin
      if Cancel then Break;
      ProgressBar.Position := I;
      lblProgress.Caption  := ActualFiles[I];
      Application.ProcessMessages;
      if not FileList.Find(ActualFiles[I], X) then
      DeleteFile(ActualFiles[I]);
    end;
    // Folders
    FindAllDirectories(ActualFolders, Directory, True);
    // Loop over Folders
    ProgressBar.Max := ActualFiles.Count;
    for I := 0 to ActualFolders.Count -1 do
    begin
      if Cancel then Break;
      ProgressBar.Position := I;
      lblProgress.Caption  := ActualFolders[I];
      Application.ProcessMessages;
      if not FolderList.Find(ActualFolders[I], X) then
      DeleteDirectory(ActualFolders[I], False);
    end;
  finally
    ActualFiles.Free;
    ActualFolders.Free;

    // Set progress to zero
    ProgressBar.Position := 0;
    lblProgress.Caption  := '';
  end;
end;

// Login
procedure TfrmMain.btnLoginClick(Sender: TObject);
var
  I : Integer;
begin
  if login(edtUsername.text, edtPassword.text) then
  begin
    Alert(AlertTitle, 'Logged in as ' + edtUsername.Text);
    edtUsername.Enabled := False;
    edtPassword.Enabled := False;
    btnLogin.Enabled    := False;
    cbInstances.Clear;
    for I := 0 to Instances.Count -1 do
    begin
      cbInstances.AddItem((Instances[I] as TInstance).Name, (Instances[I] as TInstance));
    end;
    cbInstances.Enabled := cbInstances.Items.Count > 0;
    btnStart.Enabled    := cbInstances.Enabled and (cbInstances.ItemIndex > -1);
    if cbInstances.Enabled then LoadSettings(True);
    cbInstancesChange(nil);
  end else
    Alert(AlertTitle, 'Invalid username/password combination!');
end;

// Show About message
procedure TfrmMain.AboutClick(Sender: TObject);
begin
  ShowMessage(AboutText);
end;

// Form Create
procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Caption     := ApplicationTitle;
  FInstances  := TFPObjectList.Create(True);
  FFileList   := TStringList.Create;
  FFileList.Sorted := True;
  FFolderList := TStringList.Create;
  FFolderList.Sorted := True;
  LoadSettings;
end;

// Form Destroy
procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  SaveSettings;
  FInstances.Free;
  FFileList.Free;
  FFolderList.Free;
end;

// On Select Instance
procedure TfrmMain.cbInstancesChange(Sender: TObject);
begin
  btnStart.Enabled := (cbInstances.ItemIndex > -1);
end;

// Start
procedure TfrmMain.btnStartClick(Sender: TObject);
var
  Instance : TInstance;
begin
  // Disable controls
  btnStart.Enabled := False;
  btnStop.Enabled  := True;
  cbInstances.Enabled := False;
  FileList.Clear;

  // Set Instance
  Instance := (Instances.Items[cbInstances.ItemIndex] as TInstance);
  // Convert to strm
  Alert(AlertTitle, 'Convert movies to STRM');
  ConvertMovies(Instance);
  Alert(AlertTitle, 'Convert series to STRM');
  ConvertSeries(Instance);
  // Clean up removed movies and series
  if Instance.DeleteRemoved then
  begin
    // Clean up movies
    Alert(AlertTitle, 'Clean up old movie STRM files');
    CleanUpRemoved(Instance.MoviesFolder);
    // Clean up series
    Alert(AlertTitle, 'Clean up old series STRM files');
    CleanUpRemoved(Instance.SeriesFolder);
  end;

  // Enable controls
  cbInstances.Enabled := True;
  btnStop.Enabled  := False;
  btnStart.Enabled := True;
end;

// Cancel
procedure TfrmMain.btnStopClick(Sender: TObject);
begin
  Cancel := True;
end;

// Exit
procedure TfrmMain.MenuItem2Click(Sender: TObject);
begin
  Cancel := True;
  Close;
end;

end.

