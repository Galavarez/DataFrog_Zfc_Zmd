# DataFrog_Zfc_Zmd

Сборщик ZFC и ZMD файлов для консоли Data Frog.


**Структура формата ZFC и ZMD:**

Формат ZFC и ZMD это файл состоящий из 2х частей.<br>
1 часть это превьюшка в формате raw, размерами 144х208, ориентация вертикальная.<br>
Блок 0-119807 получается 119808 байт превьюшка.<br>
Каждый пиксель состоит их 4х байтов, цвета расположены в таком порядке BGRA. Альфа канал (A) всегда 0хFF.<br>
Чтобы получить превьюшку в формате RGB надо поменять в BGRA 2 байта B и R местами.<br>

2 часть это ZIP (PKZip) архив, но немного модифицированный.<br>
У этого архива изменены точки входа. Чтобы их восстановить надо поменять следующие байты на нормальные.<br>
Находим 57 51 57 03 -> Меняем 50 4B 03 04 file header<br>
Находим 57 51 57 02 -> Меняем 50 4B 01 02 central directory file header<br>
Находим 57 51 57 01 -> Меняем 50 4B 05 06 End of central directory record<br>

После восстановления архива, надо расшифровать имя файла, которое находится в архиве.<br>
Его зашифровали функцией XOR с ключем E5.<br>
Имя в архиве встречается 2 раза.<br>
Первый раз имя встречается (это первая буква имени) с 119838 и длина его записана в блоке 119834-119835 (2 байта или word).<br>
Второй раз имя встречается в конце central directory file header и длина его все так же в блоке 119834-119835 (2 байта или word).<br>

3 часть не совсем часть то все же, это как отображается имя игры в консоле.<br>
Тут все просто оно берется из названия файла ZFC или ZMD.<br>


**Литература для понимания формата:**

Структура PKZip файла <br>
https://users.cs.jmu.edu/buchhofp/forensics/formats/pkzip.html

XOR шифр <br>
https://www.dcode.fr/xor-cipher
