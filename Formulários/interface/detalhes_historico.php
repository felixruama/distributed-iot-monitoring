<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Proteção: apenas utilizadores logados
if (!isset($_SESSION['user_email'])) {
    header("Location: index.php");
    exit();
}

// 1. Carrega o SPHandler (PDO) para consultas simples
require_once('../php/SPHandler.php');

$id_simulacao = $_GET['id'] ?? null;

if (!$id_simulacao) {
    header("Location: dashboard.php");
    exit();
}

// --- BLOCO 1: DADOS GERAIS (Via PDO/SPManager) ---
$resultados = $spManager->getData('SP_VisualizarDetalhes_Historico', [(int)$id_simulacao]);
$dados = $resultados[0] ?? null;

if (!$dados) {
    die("Erro: Simulação não encontrada.");
}

// --- BLOCO 2: ESTATÍSTICAS AVANÇADAS (Via mysqli para multi_query) ---
$stats_mvp = null;
$stats_explora = null;
$stats_sala = null;
$stats_distribuicao = []; // Agora é um array para a lista de salas

$conn = new mysqli('mysql', 'root', 'root', 'labirinto_DB');

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

        // 4. Lê Lista de Contagem Odd e Even por Sala
        if (mysqli_more_results($conn)) {
            mysqli_next_result($conn);
            $res = mysqli_store_result($conn);
            if ($res) {
                $stats_distribuicao = mysqli_fetch_all($res, MYSQLI_ASSOC);
                mysqli_free_result($res);
            }
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

    <div class="page-header" style="margin-bottom: 30px;">
        <a href="dashboard.php" style="text-decoration: none; color: #FFD700; font-weight: bold; font-size: 0.9rem;">
            ← Voltar ao Dashboard
        </a>
        <h1 style="margin: 15px 0 5px 0; font-size: 2rem; color: #000;">Detalhes da Simulação #<?php echo $dados['IDSimulacao']; ?></h1>
        <p style="color: #666; margin: 0;"><?php echo htmlspecialchars($dados['Descricao'] ?? 'Sem descrição'); ?></p>
    </div>

    <div style="display: flex; gap: 20px; margin-bottom: 30px;">
        <div style="flex:1; background:#fff; padding:20px; border-top:5px solid #FFD700; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.08);">
            <h4 style="margin:0; color:#856404; font-size: 0.85rem; text-transform: uppercase;">🏆 Marsami mais ativo</h4>
            <p style="font-size: 1.4rem; margin:15px 0 5px 0; font-weight: bold;">Marsami #<?php echo $stats_mvp['IDMarsami'] ?? '?'; ?></p>
            <span style="color: #666; font-size: 0.9rem;"><?php echo $stats_mvp['TotalPassagens'] ?? 0; ?> passagens detectadas</span>
        </div>

        <div style="flex:1; background:#fff; padding:20px; border-top:5px solid #28a745; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.08);">
            <h4 style="margin:0; color:#155724; font-size: 0.85rem; text-transform: uppercase;">🧭 Maior Explorador</h4>
            <p style="font-size: 1.4rem; margin:15px 0 5px 0; font-weight: bold;">Marsami #<?php echo $stats_explora['IDMarsami'] ?? '?'; ?></p>
            <span style="color: #666; font-size: 0.9rem;">Visitou <?php echo $stats_explora['SalasDiferentes'] ?? 0; ?> salas distintas</span>
        </div>

        <div style="flex:1; background:#fff; padding:20px; border-top:5px solid #17a2b8; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.08);">
            <h4 style="margin:0; color:#0c5460; font-size: 0.85rem; text-transform: uppercase;">🔥 Hotspot</h4>
            <p style="font-size: 1.4rem; margin:15px 0 5px 0; font-weight: bold;">Sala <?php echo $stats_sala['Sala'] ?? '?'; ?></p>
            <span style="color: #666; font-size: 0.9rem;"><?php echo $stats_sala['TotalEntradas'] ?? 0; ?> visitas totais</span>
        </div>

        <div style="flex:1; background:#fff; padding:20px; border-top:5px solid #a19010; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.08); max-height: 180px; overflow-y: auto;">
            <h4 style="margin:0 0 10px 0; color:#4b2394; font-size: 0.85rem; text-transform: uppercase;">🐆 Marsamis por Sala</h4>
            <div style="display: flex; flex-direction: column; gap: 5px;">
                <?php if (!empty($stats_distribuicao)): ?>
                    <?php foreach ($stats_distribuicao as $row): ?>
                        <div style="display:flex; justify-content:space-between; font-size: 0.8rem; border-bottom: 1px solid #eee; padding-bottom: 2px;">
                            <span><strong>Sala <?php echo $row['Sala']; ?>:</strong></span>
                            <span>Odd: <?php echo $row['NumeroMarsamisOdd']; ?> | Even: <?php echo $row['NumeroMarsamisEven']; ?></span>
                        </div>
                    <?php endforeach; ?>
                <?php else: ?>
                    <span style="font-size: 0.8rem; color: #999;">Sem dados de ocupação.</span>
                <?php endif; ?>
            </div>
        </div>
    </div>

    <section class="card" style="background: #fff; padding: 25px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.05); margin-bottom: 25px; border-left: 5px solid #FFD700;">
        <h3 style="margin: 0 0 20px 0; color: #FFD700; font-size: 1.1rem;"><i class="fas fa-info-circle"></i> Informações Gerais</h3>
        <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 40px;">
            <div>
                <div style="margin-bottom: 15px;">
                    <label style="display: block; color: #aaa; font-size: 0.75rem; text-transform: uppercase; font-weight: bold;">Estado Atual</label>
                    <strong style="font-size: 1.1rem; color: #333;"><?php echo $estados[$dados['Estado']] ?? 'Desconhecido'; ?></strong>
                </div>
                <div>
                    <label style="display: block; color: #aaa; font-size: 0.75rem; text-transform: uppercase; font-weight: bold;">Criador da Simulação</label>
                    <strong style="font-size: 1.1rem; color: #333;"><?php echo htmlspecialchars($dados['NomeCriador'] ?? 'Membro da Equipa'); ?></strong>
                </div>
            </div>

            <div>
                <div style="margin-bottom: 15px;">
                    <label style="display: block; color: #aaa; font-size: 0.75rem; text-transform: uppercase; font-weight: bold;">Duração</label>
                    <small style="color: #333; font-weight: bold;">
                        <?php echo $dados['DataHoraInicio'] ?? 'N/A'; ?> até <?php echo $dados['DataHoraFim'] ?? 'N/A'; ?>
                    </small>
                </div>
                <div style="padding: 10px; background: #fff5f5; border-radius: 6px; border: 1px solid #ffebeb;">
                    <label style="display: block; color: #d9534f; font-size: 0.75rem; text-transform: uppercase; font-weight: bold; margin-bottom: 3px;">Motivo do Encerramento</label>
                    <strong style="font-size: 0.95rem; color: #333;">
                        <?php echo htmlspecialchars($dados['motivo_fim'] ?? 'Nenhum motivo registado'); ?>
                    </strong>
                </div>
            </div>
        </div>
    </section>

    <section class="card" style="background: #fff; padding: 25px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.05);">
        <h3 style="margin: 0 0 10px 0; color: #333; font-size: 1.1rem;"><i class="fas fa-sliders-h"></i> Parâmetros de Controlo</h3>
        <p style="color: #999; font-size: 0.85rem; margin-bottom: 25px;">Estes são os limites definidos para esta simulação.</p>

        <div class="params-list" style="display: flex; flex-direction: column; gap: 8px;">
            <?php
                // Removidas as linhas de Periodicidade e Intervalo de Alertas
                $params = [
                    ['Temperaturas Críticas Alertas:', 'Mín: ' . ($dados['TempMin'] ?? '0.00') . '°C / Máx: ' . ($dados['TempMax'] ?? '0.00') . '°C'],
                    ['Ruído Crítico Alertas:', ($dados['RuidoMax'] ?? '0.00') . ' dB'],
                    ['Pontuação Acumulada:', ($dados['Pontos'] ?? '0') . ' pts']
                ];

                foreach ($params as $p): ?>
                <div style="display: flex; justify-content: space-between; align-items: center; padding: 12px 15px; background: #fcfcfc; border-radius: 6px;">
                    <span style="font-weight: bold; color: #444;"><?php echo $p[0]; ?></span>
                    <span style="color: #666;"><?php echo $p[1]; ?></span>
                </div>
            <?php endforeach; ?>
        </div>
    </section>

</div>

<?php include('includes/footer.php'); ?>