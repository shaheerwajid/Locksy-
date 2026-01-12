/*
 * Analytics Routes
 * API endpoints for analytics and reports
 */

const { Router } = require('express');
const { validarJWT } = require('../middlewares/validar-jwt');
const reportViewer = require('../services/analytics/reports/viewer');
const reportGenerator = require('../services/analytics/reports/generator');

const router = Router();

// Get daily report
router.get('/reports/daily', validarJWT, async (req, res) => {
  try {
    const date = req.query.date ? new Date(req.query.date) : new Date();
    const report = await reportViewer.getDailyReport(date);
    res.json({
      ok: true,
      report
    });
  } catch (error) {
    console.error('Error getting daily report:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener reporte diario'
    });
  }
});

// Get weekly report
router.get('/reports/weekly', validarJWT, async (req, res) => {
  try {
    const weekStart = req.query.weekStart ? new Date(req.query.weekStart) : new Date();
    const report = await reportViewer.getWeeklyReport(weekStart);
    res.json({
      ok: true,
      report
    });
  } catch (error) {
    console.error('Error getting weekly report:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener reporte semanal'
    });
  }
});

// Get monthly report
router.get('/reports/monthly', validarJWT, async (req, res) => {
  try {
    const monthStart = req.query.monthStart ? new Date(req.query.monthStart) : new Date();
    const report = await reportViewer.getMonthlyReport(monthStart);
    res.json({
      ok: true,
      report
    });
  } catch (error) {
    console.error('Error getting monthly report:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al obtener reporte mensual'
    });
  }
});

// Generate custom report
router.post('/reports/custom', validarJWT, async (req, res) => {
  try {
    const { startDate, endDate, metrics, groupBy } = req.body;
    
    if (!startDate || !endDate) {
      return res.status(400).json({
        ok: false,
        msg: 'startDate and endDate are required'
      });
    }

    const report = await reportViewer.getCustomReport({
      startDate: new Date(startDate),
      endDate: new Date(endDate),
      metrics,
      groupBy
    });

    res.json({
      ok: true,
      report
    });
  } catch (error) {
    console.error('Error generating custom report:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al generar reporte personalizado'
    });
  }
});

// List reports
router.get('/reports', validarJWT, async (req, res) => {
  try {
    const { type, limit, skip } = req.query;
    const reports = await reportViewer.listReports({
      type,
      limit: limit ? parseInt(limit) : 50,
      skip: skip ? parseInt(skip) : 0
    });
    res.json({
      ok: true,
      reports
    });
  } catch (error) {
    console.error('Error listing reports:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al listar reportes'
    });
  }
});

// Export report
router.get('/reports/:reportId/export', validarJWT, async (req, res) => {
  try {
    const { reportId } = req.params;
    const format = req.query.format || 'json';
    
    const exportData = await reportViewer.exportReport(reportId, format);

    if (format === 'csv') {
      res.setHeader('Content-Type', 'text/csv');
      res.setHeader('Content-Disposition', `attachment; filename=report-${reportId}.csv`);
      res.send(exportData.data);
    } else {
      res.json({
        ok: true,
        ...exportData
      });
    }
  } catch (error) {
    console.error('Error exporting report:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al exportar reporte'
    });
  }
});

// Generate report on demand
router.post('/reports/generate', validarJWT, async (req, res) => {
  try {
    const { type, date, weekStart, monthStart, options } = req.body;

    let report;
    switch (type) {
      case 'daily':
        report = await reportGenerator.generateDailyReport(date ? new Date(date) : new Date());
        break;
      case 'weekly':
        report = await reportGenerator.generateWeeklyReport(weekStart ? new Date(weekStart) : new Date());
        break;
      case 'monthly':
        report = await reportGenerator.generateMonthlyReport(monthStart ? new Date(monthStart) : new Date());
        break;
      case 'custom':
        report = await reportGenerator.generateCustomReport(options);
        break;
      default:
        return res.status(400).json({
          ok: false,
          msg: 'Invalid report type'
        });
    }

    res.json({
      ok: true,
      report
    });
  } catch (error) {
    console.error('Error generating report:', error);
    res.status(500).json({
      ok: false,
      msg: 'Error al generar reporte'
    });
  }
});

module.exports = router;


