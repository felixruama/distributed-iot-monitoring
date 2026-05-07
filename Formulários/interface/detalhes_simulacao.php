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

// 1. Chamar a SP_VisualizarDetalhes via Manager
$resultados = $spManager->getData('SP_VisualizarDetalhes', [(int)$id_simulacao]);
$dados = $resultados[0] ?? null;

if (!$dados) {
    die("Erro: Simulação não encontrada.");
}

// Tradução do estado para texto bonito
$estados = [
    '0' => 'Criada (Aguardando Início)',
    '1' => 'Em Execução (Ativa)',
    '2' => 'Terminada'
];

include('includes/header.php');
?>

<div class="container">
    <div class="page-header" style="margin-bottom: 30px;">
        <a href="dashboard.php" class="btn-back" style="text-decoration: none; color: var(--tech-blue); font-weight: bold;">
            ← Voltar ao Dashboard
        </a>
        <h1 style="margin-top: 20px;">Detalhes da Simulação #<?php echo $dados['IDSimulacao']; ?></h1>
        <p style="color: #666;"><?php echo htmlspecialchars($dados['Descricao'] ?? 'Sem descrição'); ?></p>
    </div>

    <section class="card" style="margin-bottom: 25px; border-left: 5px solid var(--tech-blue);">
        <h3 style="margin-top: 0; color: var(--tech-blue);"><i class="fas fa-info-circle"></i> Informações Gerais</h3>
        <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-top: 15px;">
            <div>
                <label style="display: block; color: #888; font-size: 0.85rem;">Estado Atual</label>
                <strong style="font-size: 1.1rem;"><?php echo $estados[$dados['Estado']] ?? 'Desconhecido'; ?></strong>
            </div>
            <div>
                <label style="display: block; color: #888; font-size: 0.85rem;">Criador da Simulação</label>
                <strong style="font-size: 1.1rem;"><?php echo htmlspecialchars($dados['NomeCriador'] ?? 'Desconhecido'); ?></strong>
            </div>
        </div>
    </section>

   <section class="card">
        <h3 style="margin-top: 0; color: #444;"><i class="fas fa-sliders-h"></i> Parâmetros de Controlo</h3>
        <p style="color: #888; font-size: 0.9rem; margin-bottom: 20px;">Estes são os limites definidos para esta simulação.</p>
        
        <div class="params-display" style="display: flex; flex-direction: column; gap: 15px;">
            <div class="param-row" style="display: flex; justify-content: space-between; padding: 10px; background: #f9f9f9; border-radius: 8px;">
                <span><strong>Temperaturas Críticas:</strong></span>
                <span>
                    Mín: <?php echo $dados['TempMin'] ?? 'N/A'; ?>°C / 
                    Máx: <?php echo $dados['TempMax'] ?? 'N/A'; ?>°C
                </span>
            </div>
            
            <div class="param-row" style="display: flex; justify-content: space-between; padding: 10px; background: #f9f9f9; border-radius: 8px;">
                <span><strong>Ruído Crítico:</strong></span>
                <span><?php echo $dados['RuidoMax'] ?? 'N/A'; ?> dB</span>
            </div>
            
            <div class="param-row" style="display: flex; justify-content: space-between; padding: 10px; background: #f9f9f9; border-radius: 8px;">
                <span><strong>Periodicidade de Leitura:</strong></span>
                <span><?php echo $dados['Periodicidade'] ?? 'N/A'; ?> segundos</span>
            </div>
            
            <div class="param-row" style="display: flex; justify-content: space-between; padding: 10px; background: #f9f9f9; border-radius: 8px;">
                <span><strong>Intervalo entre Alertas:</strong></span>
                <span><?php echo $dados['SegundosIntervaloAlertas'] ?? 'N/A'; ?> segundos</span>
            </div>
        </div>

        <div style="margin-top: 30px; padding: 15px; background-color: #e7f3ff; border-radius: 8px; color: #0056b3; font-size: 0.9rem;">
            <i class="fas fa-eye"></i> <strong>Modo de visualização:</strong> Apenas o criador desta simulação pode editar estes parâmetros na página de Configuração.
        </div>
    </section>