<?php
session_start();
session_unset();
session_destroy();

// Redireciona de volta para o ecrã de login que está na pasta interface
header("Location: ../interface/index.php");
exit();
?>