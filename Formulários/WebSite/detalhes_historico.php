<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

if (!isset($_SESSION['user_email'])) {
    header("Location: index.php");
    exit();
}

require_once('../php/SPHandler.php');

$id_simulacao = $_GET['id'] ?? null;

if (!$id_simulacao) {
    header("Location: historico.php");
    exit();
}

$resultados = $spManager->getData('SP_VisualizarDetalhes_Historico', [(int)$id_simulacao]);
$dados = $resultados[0] ?? null;

if (!$dados) {
    die("Erro: Registo de simulação não encontrado no arquivo.");
}

include('includes/header.php');
?>

<div class="container">
    <div class="page-header" style="margin-bottom: 30px;">
        <a href="historico.php" class="btn-back" style="text-decoration: none; color: var(--tech-blue); font-weight: bold;">
            ← Voltar ao Arquivo
        </a>
        <h1 style="margin-top: 20px;">Relatório da Simulação #<?php echo $dados['IDSimulacao']; ?></h1>
        <p style="color: #666;"><?php echo htmlspecialchars($dados['Descricao'] ?? 'Sem descrição'); ?></p>
        <span class="badge" style="background-color: #d4edda; color: #155724; padding: 6px 15px; border-radius: 12px; font-weight: bold; font-size: 0.9rem;">
            Estado: Terminada
        </span>
    </div>

    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 25px;">
        <section class="card" style="border-left: 5px solid #6c757d;">
            <h3 style="margin-top: 0; color: #444;"><i class="fas fa-history"></i> Datas do Evento</h3>
            <div style="margin-top: 15px;">
                <p><strong>Início:</strong> <?php echo $dados['DataHoraInicio'] ?? '---'; ?></p>
                <p><strong>Fim:</strong> <?php echo $dados['DataHoraFim'] ?? '---'; ?></p>
                <p><strong>Responsável:</strong> <?php echo htmlspecialchars($dados['NomeCriador']); ?></p>
            </div>
        </section>

        <section class="card" style="border-left: 5px solid var(--tech-blue);">
            <h3 style="margin-top: 0; color: var(--tech-blue);"><i class="fas fa-shield-alt"></i> Limites de Segurança</h3>
            <div style="margin-top: 15px;">
                <p><strong>Temp. Mínima:</strong> <?php echo $dados['TempMin'] ?? 'N/A'; ?>°C</p>
                <p><strong>Temp. Máxima:</strong> <?php echo $dados['TempMax'] ?? 'N/A'; ?>°C</p>
                <p><strong>Ruído Máximo:</strong> <?php echo $dados['RuidoMax'] ?? 'N/A'; ?> dB</p>
            </div>
        </section>
    </div>

    <section class="card">
        <h3 style="margin-top: 0; color: #444;"><i class="fas fa-chart-line"></i> Resumo de Leituras</h3>
        <div style="background-color: #f8f9fa; border: 2px dashed #ccc; border-radius: 10px; padding: 40px; text-align: center; color: #777; margin-top: 20px;">
            <i class="fas fa-microchip" style="font-size: 2rem; margin-bottom: 10px;"></i>
            <h4>Área Reservada para Gráficos</h4>
            <p>Os dados captados pelos sensores (MQTT) aparecerão aqui assim que ligarmos a tabela de medições.</p>
        </div>
    </section>
</div>

<?php include('includes/footer.php'); ?>