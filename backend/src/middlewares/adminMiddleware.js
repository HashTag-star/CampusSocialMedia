module.exports = (req, res, next) => {
    // 1. Auth check (should already be run by authMiddleware)
    if (!req.user) {
        return res.status(401).json({ message: 'Unauthorized' });
    }

    // 2. Role check
    if (req.user.role !== 'admin') {
        return res.status(403).json({ message: 'Access denied: Admins only' });
    }

    next();
};
