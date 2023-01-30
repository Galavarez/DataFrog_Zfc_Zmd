unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, StdCtrls,
  Buttons, Zipper, StrUtils, LCLIntf;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button_Save_Preview: TButton;
    Button_Save_Zip: TButton;
    Button_Select_Preview: TButton;
    Button_Select_Rom: TButton;
    Button_build_file: TButton;
    Button_Load_Preview_From_Console_File: TButton;
    Edit_zmd_zfc: TEdit;
    Edit_Path_Rom: TEdit;
    Edit_Name_Game: TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    GroupBox4: TGroupBox;
    GroupBox5: TGroupBox;
    Label_link_home: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    OpenDialog_Console_File: TOpenDialog;
    OpenDialog_Rom: TOpenDialog;
    OpenDialog_Select_Preview: TOpenDialog;
    OpenDialog_Zfc_Zmd: TOpenDialog;
    PaintBox_Preview: TPaintBox;
    RadioButton_zfc: TRadioButton;
    RadioButton_zmd: TRadioButton;
    procedure Button_Select_PreviewClick(Sender: TObject);
    procedure Button_Select_RomClick(Sender: TObject);
    procedure Button_build_fileClick(Sender: TObject);
    procedure Button_Load_Preview_From_Console_FileClick(Sender: TObject);
    procedure Button_Save_PreviewClick(Sender: TObject);
    procedure Button_Save_ZipClick(Sender: TObject);
    procedure Label_link_homeClick(Sender: TObject);
    procedure RadioButton_zfcChange(Sender: TObject);
    procedure RadioButton_zmdChange(Sender: TObject);
  private
    procedure Build_Change_Zip;
    procedure Build_Preview;
    procedure Build_Zip;
    function Search_Sequence_Bytes(array_byte: array of byte; search_byte: array of Byte
      ): Integer;

  public

  end;

var
  Form1: TForm1;
  MemoryStream_ZIP : TMemoryStream;
  MemoryStream_PREVIEW : TMemoryStream;

implementation

{$R *.lfm}

{ TForm1 }

// Функция поиска байтов в файле
function TForm1.Search_Sequence_Bytes( array_byte : array of byte ; search_byte : array of Byte) : Integer;
var
  len_array_byte, len_search_byte, count_true, i : Integer;
begin
  len_array_byte := Length(array_byte);
  len_search_byte := Length(search_byte);
  count_true := 0;

  // перебор
  for i := 0 to len_array_byte - 1 do
  begin
    if array_byte[i] = search_byte[count_true] then
    begin
      count_true := count_true + 1;
      if len_search_byte = count_true then
      begin
        Result := i - (len_search_byte - 1);
        Exit;
      end;
    end
    else
    begin
      count_true := 0;
    end;
  end;
  // -1 Когда пусто
  Result := -1;
end;

// Сборка превьюшки
procedure TForm1.Build_Preview();
var
    RGB : LongInt;
    B,G,R,A : Byte;
    i, j, Buf_Position : Integer;
    BGRA : array[0..3] of byte;
begin
    // Создаем поток
    MemoryStream_PREVIEW:= TMemoryStream.Create;
    MemoryStream_PREVIEW.Position:= 0;
    Buf_Position := -4;

    // Сохраняем превью по пиксельно
    for i:=0 to 207 do
    begin
       for j:=0 to 143 do
       begin
         // Получаем пиксель в RGB формате
         RGB := ColorToRGB(PaintBox_Preview.Canvas.Pixels[j,i]);
         // Раскладываем цвет на составляющие R, G, B
         RedGreenBlue(RGB, R, G, B);
         // Сохраняем цвет в порядке BGRA
         BGRA[0] := B;
         BGRA[1] := G;
         BGRA[2] := R;
         BGRA[3] := $FF; // это А афльфа канал который всегда $FF
         // Сохраняем пиксель в поток
         Buf_Position := Buf_Position + 4;
         MemoryStream_PREVIEW.Position := Buf_Position;
         MemoryStream_PREVIEW.Write(BGRA, 4);
       end;
    end;
end;

// Сборка zip архива
procedure TForm1.Build_Zip();
var
  zip: TZipper;
  name_rom, name_zip: String;
begin
    // Получаем имя rom`а
    name_rom := ExtractFileName(Edit_Path_Rom.Text);
    // Удаляем расширения из имени
    Delete(name_rom, Pos('.', name_rom), Length(name_rom));
    // Добавляем расширение zip
    name_zip := name_rom + '.zip';
    // Создаем поток
    MemoryStream_ZIP := TMemoryStream.Create;
    // Создаем архив
    zip := TZipper.Create;
    try
      // Имя архива
      zip.FileName:= name_zip;
      // Добавляем Rom в ZIP архив
      zip.Entries.AddFileEntry(Edit_Path_Rom.Text, ExtractFileName(Edit_Path_Rom.Text));
      // Сохраняем в поток
      zip.SaveToStream(MemoryStream_ZIP);
      // Сохраняем ZIP архив
      //zip.ZipAllFiles;
    finally
      // Очищаем память
      FreeAndNil(zip)
    end;

end;

// Редактируем собранный архив
procedure TForm1.Build_Change_Zip();
var
  start_zip, start_cd_zip, start_end_zip : Integer;
  len_name : Word;
  i, j: Integer;
  index_name_rom_in_zip_1, index_name_rom_in_zip_2 : Integer;
  zip : array of byte;
  one_search : array of byte = ($50, $4B, $03, $04) ;
  two_search : array of byte = ($50, $4B, $01, $02) ;
  three_search : array of byte = ($50, $4B, $05, $06) ;
  array_name_in_byte : array of byte;
begin
  // Считываем ZIP архив из потока в масив (для удобства работы)
  SetLength(zip, MemoryStream_ZIP.Size);
  MemoryStream_ZIP.Position:= 0;
  MemoryStream_ZIP.Read(zip[0], MemoryStream_ZIP.Size);

  // Находим и меняем
  // 50 4B 03 04 -> 57 51 57 03 file header
  start_zip := Search_Sequence_Bytes(  zip, one_search );
  zip[start_zip + 0] := $57;
  zip[start_zip + 1] := $51;
  zip[start_zip + 2] := $57;
  zip[start_zip + 3] := $03;

  // Длина имени файла в архиве
  len_name := zip[26] + zip[27];

  // Сохраняем имя не шифрованное (для его поиска)
  SetLength(array_name_in_byte, len_name);
  for i := 0 to len_name - 1 do
  begin
    array_name_in_byte[i] := zip[30 + i];
  end;

  // Находим и кодироем именя файла в архиве Имя 1 (ключ для XOR E5)
  index_name_rom_in_zip_1 := Search_Sequence_Bytes(  zip, array_name_in_byte );
  for i := 0 to len_name - 1 do
  begin
    zip[index_name_rom_in_zip_1 + i] := zip[index_name_rom_in_zip_1 + i] xor $E5;
  end;

  // Находим и кодироем именя файла в архиве Имя 2 (ключ для XOR E5)
  index_name_rom_in_zip_2 := Search_Sequence_Bytes(  zip, array_name_in_byte );
  for j := 0 to len_name - 1 do
  begin
    zip[index_name_rom_in_zip_2 + j] := zip[index_name_rom_in_zip_2 + j] xor $E5;
  end;

  // Находим и меняем
  // 50 4B 01 02 ->  57 51 57 02  central directory file header
  start_cd_zip := Search_Sequence_Bytes(  zip, two_search );
  zip[start_cd_zip + 0] := $57;
  zip[start_cd_zip + 1] := $51;
  zip[start_cd_zip + 2] := $57;
  zip[start_cd_zip + 3] := $02;

  // Находим и меняем
  // 50 4B 05 06 ->  57 51 57 01 End of central directory record
  start_end_zip := Search_Sequence_Bytes(  zip, three_search );
  zip[start_end_zip + 0] := $57;
  zip[start_end_zip + 1] := $51;
  zip[start_end_zip + 2] := $57;
  zip[start_end_zip + 3] := $01;

  // Сохраняем отредактированный zip массив в поток
  MemoryStream_ZIP.Position:= 0;
  MemoryStream_ZIP.Write(zip[0], Length(zip));

end;

// Загружаем превьюку из файла консоли
procedure TForm1.Button_Load_Preview_From_Console_FileClick(Sender: TObject);
var
  i,j, pos : Integer;
  buf : array[0..3] of Byte;
  B,G,R,A : Byte;
  archiv : TFileStream;
begin
  if OpenDialog_Zfc_Zmd.Execute then
  begin
    archiv := TFileStream.Create(OpenDialog_Zfc_Zmd.FileName, fmOpenRead);
    archiv.Position := 0;
    pos := -4;

    for i:=0 to 207 do
    begin
       for j:=0 to 143 do
       begin
         pos := pos + 4;
         archiv.Position := pos;
         archiv.Read(buf, 4);
         // Получаем цвета в формате BGRA
         B := buf[0];
         G := buf[1];
         R := buf[2];
         A := buf[3];
         // Выводим попиксельно превьюшку
         PaintBox_Preview.Canvas.Pixels[j,i] := RGBToColor(R, G, B);
       end;
    end;
  end;
  archiv.Free;
end;

// Загружаем превьюшку из bmp jpg png и т.д.
procedure TForm1.Button_Select_PreviewClick(Sender: TObject);
var
  Picture: TPicture;
begin
  if OpenDialog_Select_Preview.Execute then
  begin
    Picture := TPicture.Create;
    Picture.LoadFromFile(OpenDialog_Select_Preview.FileName);
    PaintBox_Preview.Canvas.Draw(0,0, Picture.Graphic);
    Picture.Free;
  end;
end;

// Кнопка выбрать rom
procedure TForm1.Button_Select_RomClick(Sender: TObject);
var
  str : String;
begin
  if OpenDialog_Rom.Execute then
  begin
    // Записываем путь к rom`у
    Edit_Path_Rom.Text:= OpenDialog_Rom.FileName;
    // Извлекаем имя и удаляем расширение файла
    str := ExtractFileName(Edit_Path_Rom.Text);
    Delete(str, Pos('.', str), Length(str));
    // Записываем его в поле название игры
    Edit_Name_Game.Text:= str;
  end;
end;

// Кнопка Собрать файл
procedure TForm1.Button_build_fileClick(Sender: TObject);
var
  FS_SAVE : TFileStream;
begin

  // Запускаем сборку
  Build_Preview;
  Build_Zip;
  Build_Change_Zip;

  // Создаем файл и сохраняем в него все потоки
  FS_SAVE := TFileStream.Create(Edit_Name_Game.Text + '.' + Edit_zmd_zfc.Text, fmCreate);
  FS_SAVE.Position:= 0;

  MemoryStream_PREVIEW.Position:=0;
  FS_SAVE.CopyFrom(MemoryStream_PREVIEW, MemoryStream_PREVIEW.Size);

  MemoryStream_ZIP.Position:=0;
  FS_SAVE.CopyFrom(MemoryStream_ZIP, MemoryStream_ZIP.Size);

  // Чистим память
  FS_SAVE.Free;
  MemoryStream_PREVIEW.Free;
  MemoryStream_ZIP.Free;

  // Сообщение
  ShowMessage('Сборка завершена!');
end;

// Кнопка Сохранить превьюшку
procedure TForm1.Button_Save_PreviewClick(Sender: TObject);
var
    RGB : LongInt;
    B,G,R,A : Byte;
    i,j: Integer;
    Save : TFileStream;
    BGRA : array[0..3] of byte;
    bmp : TBitMap;
    Picture : TPicture;
    file_name : String;
begin
    // Загружаем картинку  в PaintBox
    Button_Load_Preview_From_Console_FileClick(Self);

    // Получаем имя файла
    file_name := ExtractFileName(OpenDialog_Zfc_Zmd.FileName);
    // Удаляем расширения из имени
    Delete(file_name, Pos('.', file_name), Length(file_name));
    // Добавляем расширение
    file_name := file_name + '.bmp';

    // Сохраняем в BMP
    bmp := TBitmap.Create;
    bmp.LoadFromDevice(PaintBox_Preview.Canvas.Handle);
    bmp.SetSize(PaintBox_Preview.Width, PaintBox_Preview.Height) ;
    bmp.SaveToFile(file_name);

    // Очищаем Canvas
    PaintBox_Preview.Canvas.Clear;

    ShowMessage('Превьюшка сохранена!');
end;

// Кнопка сохранить zip
procedure TForm1.Button_Save_ZipClick(Sender: TObject);
var
  file_open : TFileStream;
  zip_save: TFileStream;
  zip : array of byte;
  len_name: Word;
  i, j: Integer;
  start_zip, start_cd_zip, start_end_zip : Integer;
  one_search : array of byte = ($57, $51, $57, $03) ;
  two_search : array of byte = ($57, $51, $57, $02) ;
  three_search : array of byte = ($57, $51, $57, $01) ;
  array_name_in_byte : array of byte;
  index_name_rom_in_zip_1 , index_name_rom_in_zip_2 : Integer;
  file_name : String;
begin
  if OpenDialog_Console_File.Execute then
  begin
    // Открываем файл консоли
    file_open := TFileStream.Create(OpenDialog_Console_File.FileName, fmOpenRead);
    // Создаем буфер под файл консоли
    SetLength(zip, file_open.Size);
    // Закидываем в буфер для удобства работы
    file_open.Position:= 0;
    file_open.Read(zip[0], file_open.Size);
    // Закрываем файл
    file_open.free;

    // Находим и меняем
    // 57 51 57 03 -> 50 4B 03 04 file header
    start_zip := Search_Sequence_Bytes(  zip, one_search );
    zip[start_zip + 0] := $50;
    zip[start_zip + 1] := $4B;
    zip[start_zip + 2] := $03;
    zip[start_zip + 3] := $04;

    // Длина имени файла в архиве
    len_name := zip[119834] + zip[119835];

    // Сохраняем имя зашифрованное (для его поиска)
    SetLength(array_name_in_byte, len_name);
    for i := 0 to len_name - 1 do
    begin
      array_name_in_byte[i] := zip[119838 + i];
    end;

    // Находим и раскодируем имя файла в архиве Имя 1 (ключ для XOR E5)
    index_name_rom_in_zip_1 := Search_Sequence_Bytes(  zip, array_name_in_byte );
    for i := 0 to len_name - 1 do
    begin
      zip[index_name_rom_in_zip_1 + i] := zip[index_name_rom_in_zip_1 + i] xor $E5;
    end;

    // Находим и раскодируем имя файла в архиве Имя 2 (ключ для XOR E5)
    index_name_rom_in_zip_2 := Search_Sequence_Bytes(  zip, array_name_in_byte );
    for j := 0 to len_name - 1 do
    begin
      zip[index_name_rom_in_zip_2 + j] := zip[index_name_rom_in_zip_2 + j] xor $E5;
    end;

    // Находим и меняем
    // 57 51 57 02 -> 50 4B 01 02  central directory file header
    start_cd_zip := Search_Sequence_Bytes(  zip, two_search );
    zip[start_cd_zip + 0] := $50;
    zip[start_cd_zip + 1] := $4B;
    zip[start_cd_zip + 2] := $01;
    zip[start_cd_zip + 3] := $02;

    // Находим и меняем
    // 57 51 57 01 -> 50 4B 05 06  End of central directory record
    start_end_zip := Search_Sequence_Bytes(  zip, three_search );
    zip[start_end_zip + 0] := $50;
    zip[start_end_zip + 1] := $4B;
    zip[start_end_zip + 2] := $05;
    zip[start_end_zip + 3] := $06;


    // Получаем имя файла
    file_name := ExtractFileName(OpenDialog_Console_File.FileName);
    // Удаляем расширения из имени
    Delete(file_name, Pos('.', file_name), Length(file_name));
    // Добавляем расширение
    file_name := file_name + '.zip';
    // Сохраняем файл
    zip_save := TFileStream.Create(file_name, fmCreate);
    zip_save.Position:=0;
    zip_save.Write(zip[119808], Length(zip) - 119808);
    zip_save.Free;

    ShowMessage('Архив извлечен!');
  end;
end;

// Ссылка на сайт программы
procedure TForm1.Label_link_homeClick(Sender: TObject);
begin
  OpenURL('https://github.com/Galavarez/DataFrog_Zfc_Zmd');
end;

// Выбор формата zfc
procedure TForm1.RadioButton_zfcChange(Sender: TObject);
begin
  Edit_zmd_zfc.Text:= 'zfc';
end;

// Выбор формата zmd
procedure TForm1.RadioButton_zmdChange(Sender: TObject);
begin
  Edit_zmd_zfc.Text:= 'zmd';
end;



end.

