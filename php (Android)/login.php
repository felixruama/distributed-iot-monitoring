<?php
include 'db_config.php';
$user_login = $_GET['username']; // O Android envia via GET
$pass_login = $_GET['password'];
$sql = "CALL SP_ValidarLogin('$user_login', '$pass_login')"; //
$result = $conn->query($sql);
if ($result && $result->num_rows > 0) {
    $row = $result->fetch_assoc();
    echo json_encode(["success" => true, "IDGrupo" => $row['Equipa']]); //
} else {
    echo json_encode(["success" => false, "message" => "Erro no Login"]);
}
?>