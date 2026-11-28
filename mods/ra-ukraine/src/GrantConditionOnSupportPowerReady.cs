using System.Linq;
using OpenRA.Mods.Common.Traits;
using OpenRA.Mods.Common.Traits.Render;
using OpenRA.Traits;

namespace OpenRA.Mods.Ukraine
{
	[Desc("Grants a condition while the actor can launch a support power and its sprite body is idle.")]
	public sealed class GrantConditionOnSupportPowerReadyInfo : TraitInfo, Requires<SupportPowerInfo>, Requires<WithSpriteBodyInfo>
	{
		[GrantedConditionReference]
		[FieldLoader.Require]
		public readonly string Condition;

		public override object Create(ActorInitializer init) => new GrantConditionOnSupportPowerReady(init.Self, this);
	}

	public sealed class GrantConditionOnSupportPowerReady : ITick, INotifySupportPower
	{
		readonly GrantConditionOnSupportPowerReadyInfo info;
		readonly WithSpriteBody body;
		int token = Actor.InvalidConditionToken;

		public GrantConditionOnSupportPowerReady(Actor self, GrantConditionOnSupportPowerReadyInfo info)
		{
			this.info = info;
			body = self.Trait<WithSpriteBody>();
		}

		void ITick.Tick(Actor self)
		{
			var manager = self.Owner.PlayerActor.Trait<SupportPowerManager>();
			var sequence = body.DefaultAnimation.CurrentSequence;
			var idle = sequence != null && sequence.Name == body.NormalizeSequence(self, body.Info.Sequence);
			var ready = idle && manager.GetPowersForActor(self).Any(instance =>
				instance.Ready && instance.Instances.Any(power =>
					power.Self == self && !power.IsTraitDisabled && !power.IsTraitPaused));

			if (ready && token == Actor.InvalidConditionToken)
				token = self.GrantCondition(info.Condition);
			else if (!ready)
				ClearCondition(self);
		}

		void ClearCondition(Actor self)
		{
			if (token != Actor.InvalidConditionToken)
				token = self.RevokeCondition(token);
		}

		void INotifySupportPower.Charged(Actor self) { }
		void INotifySupportPower.Activated(Actor self) => ClearCondition(self);
	}
}
