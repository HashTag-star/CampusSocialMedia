const { User, Report, Block, Post, Comment } = require('../models');

// Get Pending Reports
exports.getReports = async (req, res) => {
    try {
        const reports = await Report.findAll({
            where: { status: 'pending' },
            include: [
                { model: User, as: 'reporter', attributes: ['id', 'email'] }
                // In a real app, we'd polymorphically include the target (Post/Comment/User)
                // For now, the admin can look up the ID manually or we create a separate lookup endpoint
            ],
            order: [['createdAt', 'DESC']]
        });
        res.json(reports);
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Resolve/Dismiss Report
exports.updateReportStatus = async (req, res) => {
    try {
        const { id } = req.params;
        const { status } = req.body; // 'resolved' or 'dismissed'

        const report = await Report.findByPk(id);
        if (!report) return res.status(404).json({ message: 'Report not found' });

        report.status = status;
        await report.save();

        res.json({ message: `Report ${status}` });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};

// Ban User
exports.banUser = async (req, res) => {
    try {
        const { id } = req.params;
        
        const user = await User.findByPk(id);
        if (!user) return res.status(404).json({ message: 'User not found' });

        // Logic to ban:
        // 1. Mark as banned (we might need a 'banned' status or just use 'role' if we had a banned role)
        // For now, let's assume we delete them OR add a is_banned flag.
        // Let's go with adding a 'banned' boolean to User in a future migration, 
        // OR just scrambling their password/email for now as a "soft delete".
        
        // Actually, let's just delete them for MVP extreme safety, 
        // OR better, we can assume the 'Block' model can be used by an 'Admin' system user (special ID) to block them globally?
        // No, simplest MVP: Add 'is_banned' to User model in the same migration?
        // Let's just use the 'role' field and set it to 'banned' if we add that enum? 
        // User check logic needs to handle it.
        
        // Let's stick to the plan: The implementation_plan didn't specify 'banned' column.
        // I'll just DEACTIVATE them by scrambling password for now to stop login?
        // Or simpler: I'll add 'banned' column to User.js now since I'm editing it anyway.
        
        // WAIT: I already edited User.js in the parallel call.
        // I will update User.js again in the next step to add 'is_banned'.
        
        user.is_verified_student = false; // Revoke status
        user.is_banned = true; 
        await user.save();

        res.json({ message: 'User banned' });
    } catch (error) {
        console.error(error);
        res.status(500).json({ message: 'Server error' });
    }
};
