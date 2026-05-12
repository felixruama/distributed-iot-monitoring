<?php
// O host no Docker é sempre 'mysql'
$host = 'mysql'; 

// A MAGIA: Em vez de forçar o 'root', vamos apanhar as credenciais que o Android manda!
// Usamos $_REQUEST para apanhar quer venha por GET ou POST.
$user = $_REQUEST['username'] ?? '';
$pass = $_REQUEST['password'] ?? '';
$db   = $_REQUEST['database'] ?? 'labirinto_DB';

// Se o Android não enviar credenciais, bloqueamos logo a entrada!
if (empty($user) || empty($pass)) {
    die(json_encode(["success" => false, "message" => "Erro: Credenciais não fornecidas pela App."]));
}

// Tentar ligar ao MySQL com o utilizador real (ex: monitor@lab.pt)
$conn = new mysqli($host, $user, $pass, $db);

// Se a password estiver errada ou o utilizador não existir no MySQL, falha aqui!
if ($conn->connect_error) { 
    die(json_encode(["success" => false, "message" => "Erro de autenticação na BD: " . $conn->connect_error])); 
}
?>
