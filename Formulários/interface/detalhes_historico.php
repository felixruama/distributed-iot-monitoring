<?php
session_start();
// 1. Carrega o SPManager (Ele já cria a variável $spManager automaticamente, não precisas do "new")
require_once('../php/SPHandler.php'); 

$id_simulacao = $_GET['id'] ?? 999;

// --- BLOCO 1: DADOS GERAIS (Usando o teu SPManager via PDO) ---
$resultados = $spManager->getData('SP_VisualizarDetalhes_Historico', [(int)$id_simulacao]);
$dados = $resultados[0] ?? null;


// --- MUDANÇA: NOVO BLOCO ESTATÍSTICAS (MVP, Explorador, Sala) ---
$stats_mvp = null; $stats_explora = null; $stats_sala = null;

// 2. Criamos uma ligação MYSQLI isolada apenas para podermos usar o multi_query 
// (O site usa o utilizador root do Docker, independente do Android)
$conn = new mysqli('mysql', 'root', 'root', 'labirinto_DB'); 

// Só executa se ligar bem à BD
if (!$conn->connect_error) {
    if (mysqli_multi_query($conn, "CALL SP_EstatisticasFinaisSimulacao($id_simulacao)")) {
        
        // 1. Lê MVP
        $res = mysqli_store_result($conn); 
        if ($res) { $stats_mvp = mysqli_fetch_assoc($res); mysqli_free_result($res); }
        
        // 2. Lê Explorador
        if (mysqli_more_results($conn)) {
            mysqli_next_result($conn);
            $res = mysqli_store_result($conn); 
            if ($res) { $stats_explora = mysqli_fetch_assoc($res); mysqli_free_result($res); }
        }
        
        // 3. Lê Hotspot (Sala)
        if (mysqli_more_results($conn)) {
            mysqli_next_result($conn);
            $res = mysqli_store_result($conn); 
            if ($res) { $stats_sala = mysqli_fetch_assoc($res); mysqli_free_result($res); }
        }
    }
    // Fecha esta ligação específica pois já tirámos os dados
    $conn->close();
}

include('includes/header.php');
?>
<div class="container" style="padding: 20px;">
    <h1>Relatório da Simulação #<?php echo htmlspecialchars($id_simulacao); ?></h1>

    <div style="display: flex; gap: 20px; margin: 20px 0; font-family: sans-serif;">
        <div style="flex:1; background:#fff; padding:15px; border-top:5px solid #FFD700; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
            <h4 style="margin:0; color:#856404;">🏆 Marsami mais ativo</h4>
            <p style="font-size: 1.1rem; margin:10px 0;">Marsami <b>#<?php echo $stats_mvp['IDMarsami'] ?? '?'; ?></b></p>
            <small><?php echo $stats_mvp['TotalPassagens'] ?? 0; ?> passagens</small>
        </div>
        <div style="flex:1; background:#fff; padding:15px; border-top:5px solid #28a745; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
            <h4 style="margin:0; color:#155724;">🧭 Explorador</h4>
            <p style="font-size: 1.1rem; margin:10px 0;">Marsami <b>#<?php echo $stats_explora['IDMarsami'] ?? '?'; ?></b></p>
            <small>Visitou <?php echo $stats_explora['SalasDiferentes'] ?? 0; ?> salas</small>
        </div>
        <div style="flex:1; background:#fff; padding:15px; border-top:5px solid #17a2b8; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
            <h4 style="margin:0; color:#0c5460;">🔥 Hotspot</h4>
            <p style="font-size: 1.1rem; margin:10px 0;">Sala <b><?php echo $stats_sala['Sala'] ?? '?'; ?></b></p>
            <small><?php echo $stats_sala['TotalEntradas'] ?? 0; ?> visitas totais</small>
        </div>
    </div>

    <section class="card" style="margin-top: 20px; padding: 20px; background: white;">
        <h3>Dados Gerais</h3>
        <p><strong>Descrição:</strong> <?php echo $dados['Descricao'] ?? 'N/A'; ?></p>
        <p><strong>Responsável:</strong> <?php echo $dados['NomeCriador'] ?? 'N/A'; ?></p>
        <p><strong>Duração:</strong> <?php echo $dados['DataHoraInicio'] ?? 'N/A'; ?> até <?php echo $dados['DataHoraFim'] ?? 'N/A'; ?></p>
        <p><strong>Motivo de Fim:</strong> <?php echo htmlspecialchars($dados['motivo_fim'] ?? 'Desconhecido'); ?></p>
    </section>
</div>
<?php include('includes/footer.php'); ?>