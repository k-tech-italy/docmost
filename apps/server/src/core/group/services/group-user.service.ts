import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PaginationOptions } from '../../../kysely/pagination/pagination-options';
import { GroupService } from './group.service';
import { KyselyDB, KyselyTransaction } from '@docmost/db/types/kysely.types';
import { executeTx } from '@docmost/db/utils';
import { InjectKysely } from 'nestjs-kysely';
import { GroupRepo } from '@docmost/db/repos/group/group.repo';
import { GroupUserRepo } from '@docmost/db/repos/group/group-user.repo';
import { UserRepo } from '@docmost/db/repos/user/user.repo';

@Injectable()
export class GroupUserService {
  constructor(
    private groupRepo: GroupRepo,
    private groupUserRepo: GroupUserRepo,
    private groupService: GroupService,
    private userRepo: UserRepo,
    @InjectKysely() private readonly db: KyselyDB,
  ) {}

  async getGroupUsers(
    groupId: string,
    workspaceId: string,
    pagination: PaginationOptions,
  ) {
    await this.groupService.findAndValidateGroup(groupId, workspaceId);

    const groupUsers = await this.groupUserRepo.getGroupUsersPaginated(
      groupId,
      pagination,
    );

    return groupUsers;
  }

  async addUserToDefaultGroup(
    userId: string,
    workspaceId: string,
    trx?: KyselyTransaction,
  ): Promise<void> {
    await executeTx(
      this.db,
      async (trx) => {
        const defaultGroup = await this.groupRepo.getDefaultGroup(
          workspaceId,
          trx,
        );
        await this.addUserToGroup(userId, defaultGroup.id, workspaceId, trx);
      },
      trx,
    );
  }

  async addUserToGroup(
    userId: string,
    groupId: string,
    workspaceId: string,
    trx?: KyselyTransaction,
  ): Promise<void> {
    await executeTx(
      this.db,
      async (trx) => {
        await this.groupService.findAndValidateGroup(groupId, workspaceId);
        const user = await this.userRepo.findById(
          userId,
          workspaceId,
          false,
          trx,
        );

        if (!user) {
          throw new NotFoundException('User not found');
        }

        const groupUserExists = await this.groupUserRepo.getGroupUserById(
          userId,
          groupId,
          trx,
        );

        if (groupUserExists) {
          throw new BadRequestException(
            'User is already a member of this group',
          );
        }

        await this.groupUserRepo.insertGroupUser(
          {
            userId,
            groupId,
          },
          trx,
        );
      },
      trx,
    );
  }

  async removeUserFromGroup(
    userId: string,
    groupId: string,
    workspaceId: string,
  ): Promise<void> {
    const group = await this.groupService.findAndValidateGroup(
      groupId,
      workspaceId,
    );

    const user = await this.userRepo.findById(userId, workspaceId);

    if (!user) {
      throw new NotFoundException('User not found');
    }

    if (group.isDefault) {
      throw new BadRequestException(
        'You cannot remove users from a default group',
      );
    }

    const groupUser = await this.groupUserRepo.getGroupUserById(
      userId,
      groupId,
    );

    if (!groupUser) {
      throw new BadRequestException('Group member not found');
    }

    await this.groupUserRepo.delete(userId, groupId);
  }
}
