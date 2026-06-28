// GET /health — returns 200 for uptime monitoring.
module.exports = function health(req, res) {
  res.status(200).json({ status: "ok" });
};
