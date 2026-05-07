<?php
if (session_status() === PHP_SESSION_NONE) { session_start(); }
require_once('../php/SPHandler.php');

$id_simulacao = $_GET['id'] ?? null;
if (!$id_simulacao || !isset($_SESSION['IDUtilizador'])) {
    header("Location: dashboard.php"); exit();
}

// 1. Procurar os dados reais na BD
$resultados = $spManager->getData('SP_VisualizarDetalhes', [(int)$id_simulacao]);
$dados = $resultados[0] ?? null;

if (!$dados) {
    die("Erro: Simulação não encontrada.");
}

// 2. Segurança: Só o dono pode configurar
if ($dados['Criador'] != $_SESSION['IDUtilizador']) {
    header("Location: detalhes_simulacao.php?id=$id_simulacao&erro=sem_permissao"); 
    exit();
}

include('includes/header.php');
?>

<div class="container">
    <div style="margin-bottom: 30px;">
        <a href="detalhes_simulacao.php?id=<?php echo $id_simulacao; ?>" class="btn-back" style="text-decoration: none; color: var(--tech-blue); font-weight: bold;">
            ← Voltar aos Detalhes
        </a>
        <h1 style="margin-top: 20px;">Configurar Parâmetros</h1>
        <p style="color: #666;">Ajuste os limites reais para a Simulação #<?php echo $id_simulacao; ?></p>
    </div>

    <div class="card" style="max-width: 700px; margin: 0 auto;">
        <form action="../php/processar_configuracao.php" method="POST">
            <input type="hidden" name="id_simulacao" value="<?php echo $id_simulacao; ?>">

            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">
                <div class="form-group-alt">
                    <label>Temp. Mínima (°C)</label>
                    <div class="input-pill">
                        <input type="number" name="temp_min" step="0.1" value="<?php echo htmlspecialchars($dados['TempMin'] ?? ''); ?>" required>
                        <i class="fas fa-thermometer-empty"></i>
                    </div>
                </div>
                <div class="form-group-alt">
                    <label>Temp. Máxima (°C)</label>
                    <div class="input-pill">
                        <input type="number" name="temp_max" step="0.1" value="<?php echo htmlspecialchars($dados['TempMax'] ?? ''); ?>" required>
                        <i class="fas fa-thermometer-full"></i>
                    </div>
                </div>
                <div class="form-group-alt">
                    <label>Ruído Máximo (dB)</label>
                    <div class="input-pill">
                        <input type="number" name="ruido_max" step="0.1" value="<?php echo htmlspecialchars($dados['RuidoMax'] ?? ''); ?>" required>
                        <i class="fas fa-volume-up"></i>
                    </div>
                </div>
                <div class="form-group-alt">
                    <label>Periodicidade (s)</label>
                    <div class="input-pill">
                        <input type="number" name="periodicidade" value="<?php echo htmlspecialchars($dados['Periodicidade'] ?? ''); ?>" required>
                        <i class="fas fa-clock"></i>
                    </div>
                </div>
                <div class="form-group-alt" style="grid-column: span 2;">
                    <label>Intervalo entre Alertas (s)</label>
                    <div class="input-pill">
                        <input type="number" name="intervalo" value="<?php echo htmlspecialchars($dados['IntervaloAlertas'] ?? ''); ?>" required>
                        <i class="fas fa-bell"></i>
                    </div>
                </div>
            </div>

            <div style="margin-top: 30px; display: flex; justify-content: flex-end;">
                <button type="submit" class="btn-submit" style="padding: 12px 40px;">
                    Atualizar Configuração
                </button>
            </div>
        </form>
    </div>
</div>

<?php include('includes/footer.php'); ?>