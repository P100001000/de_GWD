v1.27.8
-
<?php
$str= file_get_contents('https://raw.githubusercontent.com/P100001000/de_GWD/main/version.php');
$array=explode('-', $str);
echo $array[0];
?>
