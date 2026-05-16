<?php
// Credenciais da Base de Dados da NUVEM
$host_nuvem = "194.210.86.10";
$user_nuvem = "aluno";
$pass_nuvem = "aluno";
$db_nuvem = "maze";

// Variáveis por defeito caso a BD da nuvem esteja em baixo
$ruido_critico_nuvem = "";
$temp_max_critica_nuvem = "";
$temp_min_critica_nuvem = "";

$conn_nuvem = @mysqli_connect($host_nuvem, $user_nuvem, $pass_nuvem, $db_nuvem);

if ($conn_nuvem) {
    $query_limites = "SELECT normalnoise, noisevartoleration, normaltemperature, temperaturevarhightoleration, temperaturevarlowtoleration FROM setupmaze LIMIT 1";
    $resultado = mysqli_query($conn_nuvem, $query_limites);

    if ($resultado && mysqli_num_rows($resultado) > 0) {
        $limites = mysqli_fetch_assoc($resultado);

        $ruido_critico_nuvem = $limites['normalnoise'] + $limites['noisevartoleration'];
        $temp_max_critica_nuvem = $limites['normaltemperature'] + $limites['temperaturevarhightoleration'];
        $temp_min_critica_nuvem = $limites['normaltemperature'] - $limites['temperaturevarlowtoleration'];
    }
    mysqli_close($conn_nuvem);
}
?>