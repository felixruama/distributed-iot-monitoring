<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Proteção: apenas utilizadores logados
if (!isset($_SESSION['user_email'])) {
    header("Location: index.php");
    exit();
}

require_once('../php/SPHandler.php');

$id_simulacao = $_GET['id'] ?? null;

if (!$id_simulacao) {
    header("Location: dashboard.php");
    exit();
}

// 1. DADOS GERAIS (Via PDO/SPManager)
$resultados = $spManager->getData('SP_VisualizarDetalhes_Historico', [(int)$id_simulacao]);
$dados = $resultados[0] ?? null;

if (!$dados) {
    die("Erro: Simulação não encontrada.");
}

// 2. ESTATÍSTICAS DOS MARSAMIS (Via mysqli para multi_query)
$stats_mvp = null; $stats_explora = null; $stats_sala = null;
$conn = new mysqli('mysql', 'root', 'root', 'labirinto_DB');

if (!$conn->connect_error) {
    if (mysqli_multi_query($conn, "CALL SP_EstatisticasFinaisSimulacao($id_simulacao)")) {
        // MVP
        $res = mysqli_store_result($conn);
        if ($res) { $stats_mvp = mysqli_fetch_assoc($res); mysqli_free_result($res); }
        // Explorador
        if (mysqli_more_results($conn)) {
            mysqli_next_result($conn);
            $res = mysqli_store_result($conn);
            if ($res) { $stats_explora = mysqli_fetch_assoc($res); mysqli_free_result($res); }
        }
        // Hotspot
        if (mysqli_more_results($conn)) {
            mysqli_next_result($conn);
            $res = mysqli_store_result($conn);
            if ($res) { $stats_sala = mysqli_fetch_assoc($res); mysqli_free_result($res); }
        }
    }
    $conn->close();
}

$estados = [
    '0' => 'Criada (Aguardando Início)',
    '1' => 'Em Execução (Ativa)',
    '2' => 'Terminada'
];

include('includes/header.php');
?>

<div class="container" style="padding: 20px; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">

    <!-- Cabeçalho idêntico à imagem image_9fbf44.png -->
    <div class="page-header" style="margin-bottom: 30px;">
        <a href="dashboard.php" style="text-decoration: none; color: #FFD700; font-weight: bold; font-size: 0.9rem;">
            ← Voltar ao Dashboard
        </a>
        <h1 style="margin: 15px 0 5px 0; font-size: 2rem; color: #000;">Detalhes da Simulação #<?php echo $dados['IDSimulacao']; ?></h1>
        <p style="color: #666; margin: 0;"><?php echo htmlspecialchars($dados['Descricao'] ?? 'Sem descrição'); ?></p>
    </div>

    <!-- BLOCO DE ESTATÍSTICAS (Os 3 Cards Coloridos) -->
    <div style="display: flex; gap: 20px; margin-bottom: 30px;">
        <!-- Card MVP -->
        <div style="flex:1; background:#fff; padding:20px; border-top:5px solid #FFD700; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.08);">
            <h4 style="margin:0; color:#856404; font-size: 0.9rem; text-transform: uppercase; letter-spacing: 0.5px;">🏆 Marsami mais ativo</h4>
            <p style="font-size: 1.4rem; margin:15px 0 5px 0; font-weight: bold;">Marsami #<?php echo $stats_mvp['IDMarsami'] ?? '?'; ?></p>
            <span style="color: #666; font-size: 0.9rem;"><?php echo $stats_mvp['TotalPassagens'] ?? 0; ?> passagens detectadas</span>
        </div>

        <!-- Card Explorador -->
        <div style="flex:1; background:#fff; padding:20px; border-top:5px solid #28a745; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.08);">
            <h4 style="margin:0; color:#155724; font-size: 0.9rem; text-transform: uppercase; letter-spacing: 0.5px;">🧭 Maior Explorador</h4>
            <p style="font-size: 1.4rem; margin:15px 0 5px 0; font-weight: bold;">Marsami #<?php echo $stats_explora['IDMarsami'] ?? '?'; ?></p>
            <span style="color: #666; font-size: 0.9rem;">Visitou <?php echo $stats_explora['SalasDiferentes'] ?? 0; ?> salas distintas</span>
        </div>

        <!-- Card Hotspot -->
        <div style="flex:1; background:#fff; padding:20px; border-top:5px solid #17a2b8; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.08);">
            <h4 style="margin:0; color:#0c5460; font-size: 0.9rem; text-transform: uppercase; letter-spacing: 0.5px;">🔥 Hotspot (Sala Popular)</h4>
            <p style="font-size: 1.4rem; margin:15px 0 5px 0; font-weight: bold;">Sala <?php echo $stats_sala['Sala'] ?? '?'; ?></p>
            <span style="color: #666; font-size: 0.9rem;"><?php echo $stats_sala['TotalEntradas'] ?? 0; ?> visitas totais</span>
        </div>
    </div>

    <!-- INFORMAÇÕES GERAIS (Estilo image_9fbf44.png) -->
    <section class="card" style="background: #fff; padding: 25px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); margin-bottom: 25px; border-left: 5px solid #FFD700;">
        <h3 style="margin: 0 0 20px 0; color: #FFD700; font-size: 1.1rem;"><i class="fas fa-info-circle"></i> Informações Gerais</h3>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 40px;">
            <div>
                <label style="display: block; color: #aaa; font-size: 0.75rem; text-transform: uppercase; font-weight: bold;">Estado Atual</label>
                <strong style="font-size: 1.1rem; color: #333;"><?php echo $estados[$dados['Estado']] ?? 'Desconhecido'; ?></strong>
            </div>
            <div>
                <label style="display: block; color: #aaa; font-size: 0.75rem; text-transform: uppercase; font-weight: bold;">Criador da Simulação</label>
                <strong style="font-size: 1.1rem; color: #333;"><?php echo htmlspecialchars($dados['NomeCriador'] ?? 'Membro da Equipa'); ?></strong>
            </div>
        </div>
    </section>

    <!-- PARÂMETROS DE CONTROLO (Estilo Listagem Limpa) -->
    <section class="card" style="background: #fff; padding: 25px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.05);">
        <h3 style="margin: 0 0 10px 0; color: #333; font-size: 1.1rem;"><i class="fas fa-sliders-h"></i> Parâmetros de Controlo</h3>
        <p style="color: #999; font-size: 0.85rem; margin-bottom: 25px;">Estes são os limites definidos para esta simulação.</p>

        <div class="params-list" style="display: flex; flex-direction: column; gap: 8px;">
            <?php
                $params = [
                    ['Temperaturas Críticas:', 'Mín: ' . ($dados['TempMin'] ?? '0.00') . '°C / Máx: ' . ($dados['TempMax'] ?? '0.00') . '°C'],
                    ['Ruído Crítico:', ($dados['RuidoMax'] ?? '0.00') . ' dB'],
                    ['Periodicidade de Leitura:', ($dados['Periodicidade'] ?? 'N/A') . ' segundos'],
                    ['Intervalo entre Alertas:', ($dados['IntervaloAlertas'] ?? 'N/A') . ' segundos']
                ];

                foreach ($params as $p): ?>
                <div style="display: flex; justify-content: space-between; align-items: center; padding: 12px 15px; background: #fcfcfc; border-radius: 6px;">
                    <span style="font-weight: bold; color: #444;"><?php echo $p[0]; ?></span>
                    <span style="color: #666;"><?php echo $p[1]; ?></span>
                </div>
            <?php endforeach; ?>
        </div>

        <div style="margin-top: 25px; padding: 12px; background-color: #f0f7ff; border-radius: 8px; color: #007bff; font-size: 0.85rem; display: flex; align-items: center; gap: 10px;">
            <i class="fas fa-eye"></i>
            <span><strong>Modo de visualização:</strong> Apenas o criador desta simulação pode editar estes parâmetros na página de Configuração.</span>
        </div>
    </section>

</div>

<?php include('includes/footer.php'); ?>