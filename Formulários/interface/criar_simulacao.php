<?php
if (session_status() === PHP_SESSION_NONE) { session_start(); }
if (!isset($_SESSION['IDUtilizador'])) { header("Location: index.php"); exit(); }
include('includes/header.php');
require_once('../php/get_limites_nuvem.php');
?>

<div class="container">
    <div style="margin-bottom: 30px;">
        <a href="dashboard.php" class="btn-back" style="text-decoration: none; color: var(--tech-blue); font-weight: bold;">← Voltar</a>
        <h1 style="margin-top: 20px;">Nova Simulação</h1>
    </div>

    <div class="card" style="max-width: 800px; margin: 0 auto;">
        <form action="../php/processar_criacao.php" method="POST">
            <?php if($ruido_critico_nuvem !== ""): ?>
            <div style="background-color: #e9ecef; border-left: 4px solid #17a2b8; padding: 10px; margin-bottom: 20px; border-radius: 4px; font-size: 0.9em; color: #495057;">
                <strong><i class="fas fa-info-circle"></i> Limites Críticos do Labirinto (Fim de Jogo Automático):</strong><br>
                <span style="margin-left: 20px;">
                    🌡️ <strong>Temperatura:</strong> Mínima: <?php echo $temp_min_critica_nuvem; ?> °C | Máxima: <?php echo $temp_max_critica_nuvem; ?> °C
                </span><br>
                <span style="margin-left: 20px;">
                    🔊 <strong>Ruído:</strong> Máximo: <?php echo $ruido_critico_nuvem; ?> dB
                </span>
            </div>
            <?php endif; ?>

            <div class="form-group-alt" style="margin-bottom: 30px;">
                <label>Descrição da Simulação</label>
                <div class="input-pill">
                    <input type="text" name="descricao" placeholder="Ex: Teste de Stress Sala 102" required>
                    <i class="fas fa-edit"></i>
                </div>
            </div>

            <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 20px;">
                <div class="form-group-alt">
                    <label>Temperatura Mínima Alertas (°C)</label>
                    <div class="input-pill">
                        <input type="number" name="temp_min" value="5" min="<?php echo $temp_min_critica_nuvem; ?>" required>
                        <i class="fas fa-thermometer-empty"></i>
                    </div>
                </div>
                <div class="form-group-alt">
                    <label>Temperatura Máxima Alertas (°C)</label>
                    <div class="input-pill">
                        <input type="number" name="temp_max" value="35" max="<?php echo $temp_max_critica_nuvem; ?>" required>
                        <i class="fas fa-thermometer-full"></i>
                    </div>
                </div>

                <div class="form-group-alt">
                    <label>Ruído Máximo Alertas (dB)</label>
                    <div class="input-pill">
                        <input type="number" name="ruido_max" value="25" max="<?php echo $ruido_critico_nuvem; ?>" required>
                        <i class="fas fa-volume-up"></i>
                    </div>
                </div>
                <div class="form-group-alt">
                    <label>Periodicidade (segundos)</label>
                    <div class="input-pill">
                        <input type="number" name="periodicidade" value="10" min="1" required>
                        <i class="fas fa-clock"></i>
                    </div>
                </div>

                <div class="form-group-alt full-width" style="grid-column: span 2;">
                    <label>Intervalo entre Alertas (segundos)</label>
                    <div class="input-pill">
                        <input type="number" name="intervalo" value="60" min="1" required>
                        <i class="fas fa-bell"></i>
                    </div>
                </div>
            </div>

            <div style="display: flex; gap: 15px; justify-content: flex-end; margin-top: 30px;">
                <button type="submit" class="btn-submit" style="padding: 15px 40px; font-weight: bold;">
                    Criar Simulação Agora
                </button>
            </div>
        </form>
    </div>
</div>

<?php include('includes/footer.php'); ?>