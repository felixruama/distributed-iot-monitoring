<?php
session_start();
// Chamamos o Handler que já traz a ligação à BD
require_once('../php/SPHandler.php');

$id_simulacao = $_GET['id'] ?? 1;
$id_logado = $_SESSION['IDUtilizador'];

// 1. Chamar a SP_VisualizarDetalhes via Manager
$resultados = $spManager->getData('SP_VisualizarDetalhes', [$id_simulacao]);
$dados = $resultados[0] ?? null;

if (!$dados) {
    header("Location: dashboard.php?msg=nao_encontrada");
    exit();
}

// 2. REGRA DE NEGÓCIO: Se for o criador, pode editar.
$pode_editar = ($dados['Criador'] == $id_logado);

include('includes/header.php');
?>

<div class="container">
    <div class="page-header">
        <a href="dashboard.php" class="back-link">← Voltar</a>
        <h1>
            Simulação #<?php echo $dados['IDSimulacao']; ?>
            <?php if($pode_editar): ?><i class="fas fa-pencil-alt small-icon"></i><?php endif; ?>
        </h1>
    </div>

    <hr class="header-line">

    <div class="config-grid">
        <!-- ESQUERDA: Identificação -->
        <aside class="card-sidebar">
            <h3>Identificação</h3>
            <div class="info-item">
                <label>Descrição:</label>
                <strong><?php echo htmlspecialchars($dados['Descricao']); ?></strong>
            </div>
            <div class="info-item">
                <label>Estado:</label>
                <strong><?php echo ($dados['Estado'] == '0' ? 'Criada' : ($dados['Estado'] == '1' ? 'Em Curso' : 'Terminada')); ?></strong>
            </div>
            <div class="info-item">
                <label>Equipa:</label>
                <strong><?php echo $dados['Equipa']; ?></strong>
            </div>

            <h3>Limites do Sistema</h3>
            <div class="info-item"><label>Temp. Mínima Alerta:</label> <span>10°C</span></div>
            <div class="info-item"><label>Temp. Máxima Alerta:</label> <span>60°C</span></div>
            <div class="info-item"><label>Ruído Máximo Alerta:</label> <span>80 dB</span></div>
        </aside>

        <!-- DIREITA: Formulário -->
        <main class="card-main-edit">
            <form action="../php/guardar_configuracao.php" method="POST">
                <input type="hidden" name="id_simulacao" value="<?php echo $dados['IDSimulacao']; ?>">

                <h2 class="form-title">
                    <?php echo $pode_editar ? 'Editar Parâmetros' : 'Consulta de Parâmetros'; ?>
                </h2>

                <div class="form-row-grid">
                    <div class="form-group-alt">
                        <label>Temperatura Mínima Alertas</label>
                        <div class="input-pill">
                            <input type="number" step="0.1" name="temp_min"
                                   value="<?php echo $dados['TempMinAlerta']; ?>"
                                   <?php echo !$pode_editar ? 'readonly' : ''; ?>>
                            <?php if($pode_editar): ?><i class="fas fa-pencil-alt"></i><?php endif; ?>
                        </div>
                    </div>
                    <div class="form-group-alt">
                        <label>Temperatura Máxima Alertas</label>
                        <div class="input-pill">
                            <input type="number" step="0.1" name="temp_max"
                                   value="<?php echo $dados['TempMaxAlerta']; ?>"
                                   <?php echo !$pode_editar ? 'readonly' : ''; ?>>
                            <?php if($pode_editar): ?><i class="fas fa-pencil-alt"></i><?php endif; ?>
                        </div>
                    </div>
                </div>

                <div class="form-row-grid" style="grid-template-columns: 1fr;">
                    <div class="form-group-alt">
                        <label>Ruído Máximo Alertas (dB)</label>
                        <div class="input-pill">
                            <input type="number" step="0.1" name="ruido"
                                   value="<?php echo $dados['RuidoMaxAlerta']; ?>"
                                   <?php echo !$pode_editar ? 'readonly' : ''; ?>>
                            <?php if($pode_editar): ?><i class="fas fa-pencil-alt"></i><?php endif; ?>
                        </div>
                    </div>
                </div>

                <div class="form-row-grid">
                    <div class="form-group-alt">
                        <label>Periodicidade de Leitura</label>
                        <div class="input-pill">
                            <input type="number" name="periodicidade"
                                   value="<?php echo $dados['Periodicidade']; ?>"
                                   <?php echo !$pode_editar ? 'readonly' : ''; ?>>
                            <span>seg</span>
                        </div>
                    </div>
                    <div class="form-group-alt">
                        <label>Intervalo entre Alertas</label>
                        <div class="input-pill">
                            <input type="number" name="intervalo"
                                   value="<?php echo $dados['SegundosIntervaloAlertas']; ?>"
                                   <?php echo !$pode_editar ? 'readonly' : ''; ?>>
                            <span>seg</span>
                        </div>
                    </div>
                </div>

                <?php if($pode_editar): ?>
                <div class="form-actions">
                    <button type="submit" class="btn-submit">Salvar Alterações</button>
                </div>
                <?php endif; ?>
            </form>
        </main>
    </div>
</div>

<?php include('includes/footer.php'); ?>